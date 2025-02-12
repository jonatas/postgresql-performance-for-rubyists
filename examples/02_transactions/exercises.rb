require_relative '../../config/database'
require_relative './transaction_lab'

class TransactionExercises
  class << self
    # Exercise 1: Basic Transaction Example
    def basic_transaction_example
      puts "\n=== Basic Transaction Example ==="
      # First ensure the account exists with a proper balance
      account = Account.find_or_create_by!(owner_name: 'Exercise Account') do |acc|
        acc.balance = 0.0
      end
      
      # Ensure the account has a balance (handles existing accounts)
      account.update_column(:balance, 0.0) if account.balance.nil?
      
      begin
        Account.transaction do
          puts "Initial balance: #{account.reload.balance}"  # Added reload
          account.update!(balance: account.balance + 100)
          puts "Balance after update: #{account.reload.balance}"
          
          # Simulate a failure condition
          raise "Simulated error" if rand < 0.5
        end
      rescue => e
        puts "Transaction failed: #{e.message}"
        puts "Balance after rollback: #{account.reload.balance}"
      end
    end

    # Exercise 2: Deadlock Simulation
    def deadlock_simulation
      puts "\n=== Deadlock Simulation ==="
      TransactionLab.simulate_deadlock
    end

    # Exercise 3: Isolation Level Testing
    def isolation_level_testing
      puts "\n=== Isolation Level Testing ==="
      account = Account.find_or_create_by!(owner_name: 'Isolation Test') do |acc|
        acc.balance = 1000.0
      end
      
      [:read_committed, :repeatable_read, :serializable].each do |isolation_level|
        # Reset balance before each isolation level test
        account.update!(balance: 1000.0)
        puts "\nTesting #{isolation_level} isolation:"
        puts "Reset balance to: #{account.reload.balance}"
        
        max_retries = 3
        retries = 0
        
        begin
          Account.transaction(isolation: isolation_level) do
            initial_balance = account.reload.balance
            puts "Initial balance read: #{initial_balance}"
            
            # Simulate concurrent modification in separate thread
            Thread.new do
              ActiveRecord::Base.connection_pool.with_connection do
                Account.transaction do
                  a = Account.find(account.id)
                  a.update!(balance: a.balance + 50)
                  puts "Concurrent transaction modified balance (+50)"
                end
              end
            end.join
            
            sleep(1) # Give time for concurrent modification
            
            # Read balance again - behavior will differ based on isolation level
            current_balance = account.reload.balance
            puts "Balance after concurrent modification: #{current_balance}"
            
            # Update balance
            account.update!(balance: current_balance + 100)
            puts "Final balance after our update (+100): #{account.reload.balance}"
          end
        rescue ActiveRecord::SerializationFailure => e
          retries += 1
          if retries < max_retries
            puts "Serialization failure occurred (attempt #{retries}/#{max_retries}): #{e.message}"
            sleep(0.1 * retries)  # Exponential backoff
            retry
          else
            puts "Max retries reached. Final account balance: #{account.reload.balance}"
          end
        rescue => e
          puts "Error occurred: #{e.message}"
        end
      end
    end

    # Run all exercises
    def run_all
      basic_transaction_example
      deadlock_simulation
      isolation_level_testing
    end
  end
end

# Run exercises if this file is executed directly
if __FILE__ == $0
  TransactionExercises.run_all
end 