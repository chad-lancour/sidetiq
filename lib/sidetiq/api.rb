module Sidetiq
  # Public: Sidetiq API methods.
  module API
    # Public: Returns an Array of workers including Sidetiq::Schedulable.
    def workers
      Sidetiq::Schedulable.subclasses(true)
    end

    # Public: Returns a Hash of Sidetiq::Schedule instances.
    def schedules
      workers.map(&:schedule)
    end

    # Public: Currently scheduled recurring jobs.
    #
    # worker - A Sidekiq::Worker class or String of the class name (optional)
    # block  - An optional block that can be given to which each
    #          Sidekiq::SortedEntry instance corresponding to a scheduled job will
    #          be yielded.
    #
    # Examples
    #
    #   Sidetiq.scheduled
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.scheduled(MyWorker)
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.scheduled("MyWorker")
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.scheduled do |job|
    #     # do stuff ...
    #   end
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.scheduled(MyWorker) do |job|
    #     # do stuff ...
    #   end
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.scheduled("MyWorker") do |job|
    #     # do stuff ...
    #   end
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    # Yields each Sidekiq::SortedEntry instance.
    # Returns an Array of Sidekiq::SortedEntry objects.
    def scheduled(worker = nil, &block)
      filter_set(Sidekiq::ScheduledSet.new, worker, &block)
    end

    # Public: Recurring jobs currently scheduled for retries.
    #
    # worker - A Sidekiq::Worker class or String of the class name (optional)
    # block  - An optional block that can be given to which each
    #          Sidekiq::SortedEntry instance corresponding to a scheduled job will
    #          be yielded.
    #
    # Examples
    #
    #   Sidetiq.retries
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.retries(MyWorker)
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.retries("MyWorker")
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.retries do |job|
    #     # do stuff ...
    #   end
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.retries(MyWorker) do |job|
    #     # do stuff ...
    #   end
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    #   Sidetiq.retries("MyWorker") do |job|
    #     # do stuff ...
    #   end
    #   # => [#<Sidekiq::SortedEntry>, ...]
    #
    # Yields each Sidekiq::SortedEntry instance.
    # Returns an Array of Sidekiq::SortedEntry objects.
    def retries(worker = nil, &block)
      filter_set(Sidekiq::RetrySet.new, worker, &block)
    end

    def disable(worker=nil)
      workers = worker.nil? ? Sidetiq.workers : [worker]
      keys=workers.map { |w| "sidetiq:#{w.name}:disabled" }
      Sidekiq.redis do |redis|
        keys.each do |key|
          redis.set(key, 'true')
        end
      end
    end

    def enable(worker=nil)
      workers = worker.nil? ? Sidetiq.workers : [worker]
      keys=workers.map { |w| "sidetiq:#{w.name}:disabled" }
      Sidekiq.redis do |redis|
        keys.each do |key|
          redis.del(key)
        end
      end
    end

    private

    def filter_set(set, worker, &block)
      worker = worker.constantize if worker.kind_of?(String)

      jobs = set.select do |job|
        klass = job.klass.constantize
        ret = klass.include?(Schedulable)
        ret = ret && klass == worker if worker
        ret
      end

      jobs.each(&block) if block_given?

      jobs
    end
  end
end
