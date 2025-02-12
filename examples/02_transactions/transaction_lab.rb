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

      # Reset balances to initial state
      Account.transaction do
        account1.update!(balance: 1000)
        account2.update!(balance: 1000)
      end

      thread1 = Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            Account.transaction do
              # Lock both records in a consistent order to prevent deadlock
              accounts = Account.lock.where(id: [account1.id, account2.id]).order(:id)
              a1, a2 = accounts[0], accounts[1]
              
              puts "Thread 1: Locked account1"
              sleep(1) # Force deadlock scenario
              puts "Thread 1: Trying to lock account2"
              a2.update!(balance: a2.balance + 100)
              puts "Thread 1: Transaction completed"
            end
          end
        rescue ActiveRecord::Deadlocked, PG::TRDeadlockDetected => e
          puts "Thread 1: Deadlock detected and transaction rolled back"
        rescue => e
          puts "Thread 1: Unexpected error: #{e.message}"
        end
      end

      thread2 = Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            Account.transaction do
              # Lock both records in reverse order to create deadlock
              accounts = Account.lock.where(id: [account1.id, account2.id]).order(id: :desc)
              a1, a2 = accounts[0], accounts[1]
              
              puts "Thread 2: Locked account2"
              puts "Thread 2: Trying to lock account1"
              a1.update!(balance: a1.balance - 100)
              puts "Thread 2: Transaction completed"
            end
          end
        rescue ActiveRecord::Deadlocked, PG::TRDeadlockDetected => e
          puts "Thread 2: Deadlock detected and transaction rolled back"
        rescue => e
          puts "Thread 2: Unexpected error: #{e.message}"
        end
      end

      [thread1, thread2].each(&:join)
      
      # Reload accounts to get final state
      account1.reload
      account2.reload
      
      puts "\nFinal account balances:"
      puts "Alice's balance: #{account1.balance}"
      puts "Bob's balance: #{account2.balance}"
    end
  end
end

# Run the simulation if this file is executed directly
if __FILE__ == $0
  puts "Starting deadlock simulation..."
  TransactionLab.simulate_deadlock
end 