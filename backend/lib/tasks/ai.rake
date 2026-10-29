namespace :ai do
  desc "Set the fake provider mode for the running server (heuristic|malformed|timeout|error|slow, optional _once suffix)"
  task :fake_mode, [ :mode ] => :environment do |_task, args|
    Ai::Providers::Fake.write_mode!(args[:mode] || "heuristic")
    puts "Fake AI mode set to #{args[:mode] || 'heuristic'} (#{Ai::Providers::Fake.mode_file})."
  end

  namespace :fake_mode do
    desc "Clear the fake provider mode (back to heuristic or FAKE_AI_MODE)"
    task clear: :environment do
      Ai::Providers::Fake.clear_mode!
      puts "Fake AI mode cleared."
    end
  end
end
