require 'sidekiq/web'

module Sidetiq
  module Web
    VIEWS = File.expand_path('views', File.dirname(__FILE__))

    def self.registered(app)
      app.get "/sidetiq" do
        @workers = Sidetiq.workers
        @time = Sidetiq.clock.gettime
        erb File.read(File.join(VIEWS, 'sidetiq.erb')), locals: {view_path: VIEWS}
      end

      app.get "/sidetiq/locks" do
        @locks = Sidetiq::Lock::Redis.all.map(&:meta_data)

        erb File.read(File.join(VIEWS, 'locks.erb')), locals: {view_path: VIEWS}
      end

      app.get "/sidetiq/:name/schedule" do
        halt 404 unless (name = params[:name])

        @time = Sidetiq.clock.gettime

        @worker = Sidetiq.workers.detect do |worker|
          worker.name == name
        end

        @schedule = @worker.schedule

        erb File.read(File.join(VIEWS, 'schedule.erb')), locals: {view_path: VIEWS}
      end

      app.get "/sidetiq/:name/history" do
        halt 404 unless (name = params[:name])

        @time = Sidetiq.clock.gettime

        @worker = Sidetiq.workers.detect do |worker|
          worker.name == name
        end

        @history = Sidekiq.redis do |redis|
          redis.lrange("sidetiq:#{Sidetiq.namespace(name)}:history", 0, -1)
        end

        erb File.read(File.join(VIEWS, 'history.erb')), locals: {view_path: VIEWS}
      end

      app.post "/sidetiq/:name/trigger" do
        halt 404 unless (name = params[:name])

        worker = Sidetiq.workers.detect do |worker|
          worker.name == name
        end

        key = "sidetiq:#{Sidetiq.namespace(worker)}"
        time_f = Time.now.to_f
        next_run = Sidekiq.redis do |redis|
          (redis.get("#{key}:next") || -1).to_f
        end

        case worker.instance_method(:perform).parameters.size
          when 0
            worker.perform_async
          when 1
            worker.perform_async(next_run)
          else
            worker.perform_async(next_run, time_f)
        end

        redirect "#{root_path}sidetiq"
      end

      app.post "/sidetiq/:name/unlock" do
        halt 404 unless (name = params[:name])

        Sidetiq::Lock::Redis.new(name).unlock!

        redirect "#{root_path}sidetiq/locks"
      end
    end
  end
end

Sidekiq::Web.register(Sidetiq::Web)
Sidekiq::Web.tabs["Sidetiq"] = "sidetiq"

