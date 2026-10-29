namespace :eval do
  desc 'Run the challenge evaluation cases: bin/rails "eval:run[fake]" or bin/rails "eval:run[anthropic]"'
  task :run, [ :provider ] => :environment do |_task, args|
    name = args[:provider] || "fake"
    runner = Evaluation::Runner.new(provider_name: name)
    outcomes = runner.run
    provider = runner.provider

    report = <<~MD
      # Evaluation run

      - Provider: #{provider.name} (#{provider.model || 'n/a'})
      - Prompt version: #{Ai::Prompt::VERSION}
      - Executed: #{Time.current.iso8601}
      - Command: bin/rails "eval:run[#{name}]"

      #{Evaluation::Runner.to_markdown(outcomes)}
    MD

    dir = Rails.root.join("tmp/evaluation")
    FileUtils.mkdir_p(dir)
    path = dir.join("#{name}-#{Time.current.strftime('%Y%m%dT%H%M%S')}.md")
    File.write(path, report)
    puts report
    puts "Saved to #{path}"
  end
end
