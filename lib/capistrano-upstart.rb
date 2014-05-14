require "capistrano-upstart/version"
require "capistrano/configuration/actions/file_transfer_ext"
require "capistrano/configuration/resources/file_resources"

module Capistrano
  module Upstart
    def self.extended(configuration)
      configuration.load {
        namespace(:deploy) {
          desc("Start upstart service.")
          task(:start, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("upstart:start")
          }

          desc("Stop upstart service.")
          task(:stop, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("upstart:stop")
          }

          desc("Restart upstart service.")
          task(:restart, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("upstart:reload")
          }
        }

        namespace(:upstart) {
          _cset(:upstart_template_source_path, File.join(File.dirname(__FILE__), 'templates'))
          _cset(:upstart_template_files) {
            [
              "#{upstart_service_name}.conf",
              "upstart.conf",
            ]
          }

          _cset(:upstart_service_file) {
            "/etc/init/#{upstart_service_name}.conf"
          }
          _cset(:upstart_service_name) {
            abort("You must set upstart_service_name explicitly.")
          }

          _cset(:upstart_start_on, { :runlevel => "[2345]" })
          _cset(:upstart_stop_on, { :runlevel => "[016]" })
          _cset(:upstart_env, {})
          _cset(:upstart_export) {
            upstart_env.keys
          }
          _cset(:upstart_script) {
            abort("You must specify either :upstart_exec or :upstart_script.")
          }

          _cset(:upstart_chdir) { current_path }
          _cset(:upstart_console, "none")
          _cset(:upstart_respawn, true)
          _cset(:upstart_options) {{
            "author" => fetch(:upstart_author, "unknown").to_s.dump,
            "chdir" => upstart_chdir,
            "console" => upstart_console,
            "description" => fetch(:upstart_description, application).to_s.dump,
            "respawn" => upstart_respawn,
          }}

          desc("Setup upstart service.")
          task(:setup, :roles => :app, :except => { :no_release => true }) {
            transaction {
              configure
            }
          }
          after "deploy:setup", "upstart:setup"

          _cset(:upstart_default_configure_options) {{
            :install => :if_modified, :run_method => :sudo,
            :owner => "root", :group => "root", :mode => "644",
          }}
          task(:configure, :roles => :app, :except => { :no_release => true }) {
            t = upstart_template_files.find { |f|
              File.file?(File.join(upstart_template_source_path, "#{f}.erb")) or File.file?(File.join(upstart_template_source_path, f))
            }
            abort("Could not find template for upstart configuration file for `#{upstart_service_name}'.") unless t
            safe_put(template(t, :path => upstart_template_source_path),
                     upstart_service_file,
                     upstart_default_configure_options.merge(fetch(:upstart_configure_options, {})))
          }

          desc("Start upstart service.")
          task(:start, :roles => :app, :except => { :no_release => true }) {
            run("#{sudo} start #{upstart_service_name.dump}")
          }

          desc("Stop upstart service.")
          task(:stop, :roles => :app, :except => { :no_release => true }) {
            run("#{sudo} stop #{upstart_service_name.dump}")
          }

          desc("Restart upstart service.")
          task(:restart, :roles => :app, :except => { :no_release => true }) {
            run("#{sudo} restart #{upstart_service_name.dump} || #{sudo} start #{upstart_service_name.dump}")
          }

          desc("Reload upstart service.")
          task(:reload, :roles => :app, :except => { :no_release => true }) {
            run("#{sudo} reload #{upstart_service_name.dump} || #{sudo} start #{upstart_service_name.dump}")
          }

          desc("Show upstart service status.")
          task(:status, :roles => :app, :except => { :no_release => true }) {
            run("#{sudo} status #{upstart_service_name.dump}")
          }
        }
      }
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::Upstart)
end

# vim:set ft=ruby :
