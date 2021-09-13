use near_sdk::borsh::{self, BorshDeserialize, BorshSerialize};
use near_sdk::{env, near_bindgen, AccountId, Promise};
near_sdk::setup_alloc!();

#[near_bindgen]
#[derive(Default, BorshDeserialize, BorshSerialize)]
pub struct Storage {
    computer: Computer,
    counter: Counter,
}

#[near_bindgen]
impl Storage {
    #[init]
    pub fn new(owner: String) -> Self {
        Self {
            computer: Computer {
                owner,
                ..Computer::default()
            },
            counter: Counter { val: 3 },
        }
    }

    // Counter

    pub fn get_num(&self) -> i8 {
        return self.counter.val;
    }

    pub fn increment(&mut self) {
        // Note: Unprotected addition (see https://doc.rust-lang.org/std/primitive.i8.html#method.wrapping_add)
        self.counter.val += 1;
        let log_message = format!("Increased number to {}", self.counter.val);
        env::log(log_message.as_bytes());
        after_counter_change();
    }

    pub fn decrement(&mut self) {
        // Note: Unprotected substraction (see https://doc.rust-lang.org/std/primitive.i8.html#method.wrapping_add)
        self.counter.val -= 1;
        let log_message = format!("Decreased number to {}", self.counter.val);
        env::log(log_message.as_bytes());
        after_counter_change();
    }

    pub fn reset(&mut self) {
        self.counter.val = 0;
        env::log(b"Reset counter to zero");
    }

    // Storage

    pub fn add_file(&mut self, name: String) {
        self.computer.disk.folder.files.push(name);
        self.computer.disk.permissions.push(Permission {
            id: 1,
            writable: true,
        });
    }

    // Payable & Transfers

    #[payable]
    pub fn payable_annotated_view() {
        env::log("Burning fees received!.".as_bytes());
    }

    #[payable]
    pub fn payable_annotated_mut(&mut self) {
        env::log("Burning fees received!.".as_bytes());
    }

    pub fn payable_no_annotation() {
        env::log("This will actually panic when deposit is part of the transaction, because we are not flagged as payable.".as_bytes());
    }

    pub fn transfer_money(&mut self, to: AccountId, amount: u64) {
        Promise::new(to).transfer(amount as u128);
    }

    // Args

    pub fn no_args() {}
}

fn after_counter_change() {
    env::log("Make sure you don't overflow, my friend.".as_bytes());
}

//
/// Counter (Simple Structure, No Arguments)
//

#[derive(Default, BorshDeserialize, BorshSerialize)]
pub struct Counter {
    val: i8,
}

//
/// Computer (Complex Structure)
//

#[derive(Default, BorshDeserialize, BorshSerialize)]
pub struct Computer {
    owner: String,
    disk: Disk,
}

#[derive(Default, BorshDeserialize, BorshSerialize)]
pub struct Disk {
    name: String,
    folder: Folder,
    permissions: Vec<Permission>,
}

#[derive(Default, BorshDeserialize, BorshSerialize)]
pub struct Folder {
    id: i8,
    files: Vec<String>,
}

#[derive(Default, BorshDeserialize, BorshSerialize)]
pub struct Permission {
    id: i64,
    writable: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use near_sdk::MockedBlockchain;
    use near_sdk::{testing_env, VMContext};

    // part of writing unit tests is setting up a mock context
    // in this example, this is only needed for env::log in the contract
    // this is also a useful list to peek at when wondering what's available in env::*
    fn get_context(input: Vec<u8>, is_view: bool) -> VMContext {
        VMContext {
            current_account_id: "alice.testnet".to_string(),
            signer_account_id: "robert.testnet".to_string(),
            signer_account_pk: vec![0, 1, 2],
            predecessor_account_id: "jane.testnet".to_string(),
            input,
            block_index: 0,
            block_timestamp: 0,
            account_balance: 0,
            account_locked_balance: 0,
            storage_usage: 0,
            attached_deposit: 0,
            prepaid_gas: 10u64.pow(18),
            random_seed: vec![0, 1, 2],
            is_view,
            output_data_receivers: vec![],
            epoch_height: 19,
        }
    }

    // mark individual unit tests with #[test] for them to be registered and fired
    #[test]
    fn increment() {
        // set up the mock context into the testing environment
        let context = get_context(vec![], false);
        testing_env!(context);
        // instantiate a contract variable with the counter at zero
        let mut contract = Counter { val: 0 };
        contract.increment();
        println!("Value after increment: {}", contract.get_num());
        // confirm that we received 1 when calling get_num
        assert_eq!(1, contract.get_num());
    }

    #[test]
    fn decrement() {
        let context = get_context(vec![], false);
        testing_env!(context);
        let mut contract = Counter { val: 0 };
        contract.decrement();
        println!("Value after decrement: {}", contract.get_num());
        // confirm that we received -1 when calling get_num
        assert_eq!(-1, contract.get_num());
    }

    #[test]
    fn increment_and_reset() {
        let context = get_context(vec![], false);
        testing_env!(context);
        let mut contract = Counter { val: 0 };
        contract.increment();
        contract.reset();
        println!("Value after reset: {}", contract.get_num());
        // confirm that we received -1 when calling get_num
        assert_eq!(0, contract.get_num());
    }
}
