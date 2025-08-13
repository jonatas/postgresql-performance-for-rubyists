require_relative '../../config/database'

class Account < ActiveRecord::Base
  def self.transfer(from_account, to_account, amount, max_retries: 3)
    retries = 0
    begin
      transaction do
        # Lock accounts in the order they were passed in (this can cause deadlocks!)
        from = Account.lock.find(from_account.id)
        sleep(0.1) # Increase chance of deadlock
        to = Account.lock.find(to_account.id)
        
        # Verify sufficient funds
        raise InsufficientFundsError, "Insufficient balance" if from.balance < amount
        
        puts "Transferring #{amount} from #{from.owner_name} to #{to.owner_name}"
        # Perform the transfer
        from.update!(balance: from.balance - amount)
        to.update!(balance: to.balance + amount)
        puts "Transfer complete"
        puts "#{from.owner_name} balance: #{from.balance}"
        puts "#{to.owner_name} balance: #{to.balance}"
      end
    rescue ActiveRecord::Deadlocked, PG::TRDeadlockDetected => e
      retries += 1
      if retries <= max_retries
        puts "Deadlock detected (attempt #{retries}/#{max_retries}): #{e.message}"
        puts "Retrying transfer from #{from_account.owner_name} to #{to_account.owner_name} of #{amount}"
        sleep(rand) # Add random backoff
        retry
      else
        puts "Max retries reached. Cancelling transaction."
        raise
      end
    end
  end
  
  class InsufficientFundsError < StandardError; end
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
      alice = Account.find_or_create_by!(owner_name: 'Alice')
      bob = Account.find_or_create_by!(owner_name: 'Bob')

      puts "\nInitial balances:"
      puts "Alice: #{alice.balance}, Bob: #{bob.balance}"

      # Reset balances to initial state
      Account.transaction do
        alice.update!(balance: 1000)
        bob.update!(balance: 1000)
      end

      puts "\nReset balances:"
      puts "Alice: #{alice.reload.balance}, Bob: #{bob.reload.balance}"

      puts "\nStarting concurrent transfers (this should cause a deadlock)..."
      
      thread1 = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          begin
            puts "👱‍♀️ Alice initiating transfer..."
            Account.transfer(alice, bob, 100)
          rescue => e
            puts "👱‍♀️ Alice's transfer failed: #{e.message}"
          end
        end
      end

      thread2 = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          begin
            puts "👨 Bob initiating transfer..."
            Account.transfer(bob, alice, 100)
          rescue => e
            puts "👨 Bob's transfer failed: #{e.message}"
          end
        end
      end

      [thread1, thread2].each(&:join)
      
      # Reload accounts to get final state
      alice.reload
      bob.reload
      
      puts "\nFinal account balances:"
      puts "Alice's balance: #{alice.balance}"
      puts "Bob's balance: #{bob.balance}"
      
      puts "\nNote: If you don't see a deadlock, try running the simulation again."
      puts "Deadlocks are timing-dependent and may not occur every time."
    end
  end
end

# Run the simulation if this file is executed directly
if __FILE__ == $0
  puts "Starting deadlock simulation..."
  TransactionLab.simulate_deadlock
end 