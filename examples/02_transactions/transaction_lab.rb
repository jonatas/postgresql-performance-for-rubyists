require_relative '../../config/database'

class Account < ActiveRecord::Base
end

# Create accounts table if it doesn't exist
unless ActiveRecord::Base.connection.table_exists?('accounts')
  ActiveRecord::Base.connection.create_table :accounts do |t|
    t.decimal :balance, precision: 10, scale: 2
    t.string :owner_name
    t.timestamps
  end
end

class TransactionLab
  class << self
    def simulate_deadlock
      # Create test accounts if they don't exist
      account1 = Account.find_or_create_by!(owner_name: 'Alice') { |a| a.balance = 1000 }
      account2 = Account.find_or_create_by!(owner_name: 'Bob') { |a| a.balance = 1000 }

      thread1 = Thread.new do
        Account.transaction do
          account1.lock!
          puts "Thread 1: Locked account1"
          sleep(1) # Force deadlock
          puts "Thread 1: Trying to lock account2"
          account2.update!(balance: account2.balance + 100)
        end
      end

      thread2 = Thread.new do
        Account.transaction do
          account2.lock!
          puts "Thread 2: Locked account2"
          puts "Thread 2: Trying to lock account1"
          account1.update!(balance: account1.balance - 100)
        end
      end

      [thread1, thread2].each(&:join)
    rescue ActiveRecord::Deadlocked => e
      puts "Deadlock detected: #{e.message}"
    end
  end
end

# Run the simulation if this file is executed directly
if __FILE__ == $0
  puts "Starting deadlock simulation..."
  TransactionLab.simulate_deadlock
end 