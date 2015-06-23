class Mboy
  @hipchat_apikey = ''

  def initialize()
    set :hipchat_room, 'Dev Team'
    set :human, %x{git config user.name}.strip
    set :log_level, :error
    set :use_sudo, false
  end

  def self.deploy_starting_message()
    before :starting, :mboy_deploy do
      on roles(:all) do
        puts '


           ##     ##    #####    ##    ##   ##   ##  #######  #######         #####      #####   ##    ##
          ###    ###   #######   ###   ##   ##  ##   #######  #######         ######    #######  ##    ##
          ####   ###  ##     ##  ###   ##   ## ##    ##       ##              ##  ##   ##     ## ##    ##
          ####  ####  ##     ##  ####  ##   ####     ##       ##              ##  ##   ##     ##  ##  ##
          ## #### ##  ##     ##  ## ## ##   ####     ######   ######   ####   ######   ##     ##   ####
          ##  ##  ##  ##     ##  ## ## ##   #####    ######   ######   ####   ######   ##     ##    ##
          ##  ##  ##  ##     ##  ##  ####   ## ###   ##       ##              ##   ##  ##     ##    ##
          ##      ##  ##     ##  ##   ###   ##  ##   ##       ##              ##   ##  ##     ##    ##
          ##      ##   #######   ##   ###   ##   ##  #######  #######         #######   #######     ##
          ##      ##    #####    ##    ##   ##   ### #######  #######         ######     #####      ##


        '.yellow

        puts '                        ******************** DEPLOYMENT INITIATED *********************'
        puts '                        You are now starting a Monkee-Boy deployment to the Habitat.'.green
        puts '                        ***************************************************************

        '
      end
    end
  end

  def self.tag_release()
    after :updated, :tagrelease do
      on roles(:web) do
        within release_path do
          set(:current_revision, capture(:cat, 'REVISION'))
          resolved_release_path = capture(:pwd, "-P")
          set(:release_name, resolved_release_path.split('/').last)
        end
      end

      run_locally do
        tag_msg = "Deployed by #{fetch :human} to #{fetch :stage} as #{fetch :release_name}"
        tag_name = "#{fetch :stage }-#{fetch :release_name}"
        execute :git, %(tag #{tag_name} #{fetch :current_revision} -m "#{tag_msg}")
        execute :git, "push --tags origin"
      end
    end

    before :tagrelease, :deploy_step_beforetag do
      on roles(:all) do
        print 'Creating a git tag for this stage on current release......'
      end
    end

    after :tagrelease, :deploy_step_aftertag do
      on roles(:all) do
        puts '✔'.green
      end
    end

    # Couldn't find a better place for this besides in this method.
    before :finished, :setsymlink do
      on roles(:web) do
        within deploy_to do
          execute :ln, '-s', 'current', 'public_html'
        end
      end
    end

    before :setsymlink, :deploy_step_beforesymlink do
      on roles(:all) do
        print 'Creating the public_html symlink on current release......'
      end
    end

    after :setsymlink, :deploy_step_aftersymlink do
      on roles(:all) do
        puts '✔'.green
      end
    end
  end

  def self.deploy_steps()
    before :check, :deploy_step_beforecheck do
      on roles(:all) do
        print 'Checking deployment environment......'
      end
    end

    after :check, :deploy_step_aftercheck do
      on roles(:all) do
        puts '✔'.green
      end
    end

    before :updating, :deploy_step_beforeupdating do
      on roles(:all) do
        print 'Creating new release from git repo and creating symlinks for shared......'
      end
    end

    after :updating, :deploy_step_afterupdating do
      on roles(:all) do
        puts '✔'.green
      end
    end

    before :publishing, :deploy_step_beforepublishing do
      on roles(:all) do
        print 'Publishing new release by creating symlink from current......'
      end
    end

    after :publishing, :deploy_step_afterpublishing do
      on roles(:all) do
        puts '✔'.green
      end
    end

    before :finishing, :deploy_step_beforefinishing do
      on roles(:all) do
        print 'Cleaning up tmp directories from deployment......'
      end
    end

    after :finishing, :deploy_step_afterfinishing do
      on roles(:all) do
        puts '✔'.green
      end
    end

    before :reverting, :deploy_step_beforereverting do
      on roles(:all) do
        print 'Reverting environment to previous release......'
      end
    end

    after :reverting, :deploy_step_afterreverting do
      on roles(:all) do
        puts '✔'.green
      end
    end

    before :finishing_rollback, :deploy_step_afterfinishing_rollback do
      on roles(:all) do
        print 'Finishing rollback and cleaning up tmp directories......'
      end
    end

    after :finishing_rollback, :deploy_step_afterfinishing_rollback do
      on roles(:all) do
        puts '✔'.green
      end
    end

    after :finished, :deploy_step_afterfinished do
      on roles(:all) do
        print 'Your deployment was successful. Don\'t forget to be a responsible developer and QA your deployment.'.green
      end
    end
  end

  def self.hipchat_notify()
    after :finishing, :deploy_message do
      ask(:deployment_message, '')
      client = HipChat::Client.new(@hipchat_apikey)
      client[fetch(:hipchat_room)].send('Habitat', '(success) ' + fetch(:project_name) + ' (' + fetch(:deploy_env) + ') was successfully deployed to the habitat by ' + fetch(:human) + '. ' + fetch(:deployment_message), :color => 'green', :message_format => 'text')
    end

    after :finishing_rollback, :rollback_message do
      client = HipChat::Client.new(@hipchat_apikey)
      client[fetch(:hipchat_room)].send('Habitat', '(pokerface) ' + fetch(:project_name) + ' (' + fetch(:deploy_env) + ') was successfully rolledback to a previous deployment on the habitat by ' + fetch(:human) + '.', :color => 'yellow', :message_format => 'text')
    end

    after :failed, :failed_message do
      client = HipChat::Client.new(@hipchat_apikey)
      client[fetch(:hipchat_room)].send('Habitat', '(facepalm) ' + fetch(:project_name) + ' (' + fetch(:deploy_env) + ') failed to be deployed to the habitat by ' + fetch(:human) + '.', :color => 'red', :message_format => 'text')
    end
  end
end
