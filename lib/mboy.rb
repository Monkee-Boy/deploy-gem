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


        '

        puts '                        ******************** DEPLOYMENT INITIATED *********************'
        puts '                                 You are now starting a Monkee-Boy deployment.'
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

    # Couldn't find a better place for this besides in this method.
    before :finished, :setsymlink do
      on roles(:web) do
        within deploy_to do
          execute :ln, '-s', 'current', 'public_html'
        end
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
