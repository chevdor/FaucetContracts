pragma solidity ^0.4.6;
/**
 * Standard 'owned' contract.
 */
contract owned {
	address owner;
	function owned() {
		owner = msg.sender;
	}

	modifier ownerOnly () {
		if (msg.sender != owner) throw;
		_;
	}
}

contract ThrottledFaucet is owned {
	uint public VERSION = 1;

	address faucet; 			// who can call this contract
	uint public cooldown; 		// how often can user call the faucet
	uint public max;			// what is the max amount users can get
	bool public conservative;	// In conservative mode, the faucet limits 
								// the payments to prevent totally drying out.
	uint maxThrottleCount = 3;  // user is throttled N times => blacklist
	bool public enabled;		// allows pausing the faucet

	struct entry {
		uint lastPayment;
		uint totalPaid;
		uint throttleCount;
	}

	mapping (string => entry) history;
	mapping (string => bool) blacklist;

	event Sent(uint amount, address to, string id);
	event Throttled(string id, uint count);
	event Blacklisted(string id);
	event StatusChanged(bool enabled);
	event Donation(address donator, uint amount);
	event Debug(uint gas, uint price);

	modifier faucetOnly () {
		if (msg.sender != faucet) throw;
		_;
	}

	function setFaucet(address _faucet) ownerOnly {
		faucet = _faucet;
	}

	function setCooldown(uint _cooldown) ownerOnly {
		cooldown = _cooldown;
	}

	function setMax(uint _max) ownerOnly {
		max = _max;
	}

	function setConservative(bool _conservative) ownerOnly {
		conservative = _conservative;
	}

	function ThrottledFaucet(address _faucet, uint _cooldown, uint _max, bool _conservative) {
		if (_faucet == 0x0) throw;
		faucet = _faucet;
		cooldown = _cooldown; // 24h = 24*60*60 = 86400. 1h = 60*60 = 3600
		max = _max;
		conservative = _conservative;
		enabled = true;
	}
	
	function setBlacklist(string id, bool state) ownerOnly {
		blacklist[id] = state;
	}

	/**
	 * Only a trusted faucet account can call this functin as we
	 * trust it will provide a valid id such as a hash, email, etc...
	 * While this faucet contract needs to be funded, the faucet account
	 * only need a little Ether to pay its fees. 
	 */
	function send(string _id, address _recipient, uint _amount) payable faucetOnly {
		// var gasStart = msg.gas;
		if (blacklist[_id]) throw;

		if (_amount > max) _amount = max;
		uint8 n = 10; 

		if (conservative) {
			if (this.balance < max * n)
				_amount -= n/100 * _amount;
		}

		entry e = history[_id];
		if (e.lastPayment > 0) {					// returning user
			if (now - e.lastPayment < cooldown) {
				e.throttleCount += 1;
				Throttled(_id, e.throttleCount);

				if (e.throttleCount >= maxThrottleCount) {
					blacklist[_id] = true;
					Blacklisted(_id);
				}
			}
			else {
				// if (!blacklist[_id]) { // already checked
					e.lastPayment = now;
					e.totalPaid += _amount;
					e.throttleCount = 0;
					if (!_recipient.send(_amount)) throw;
					Sent(_amount, _recipient, _id);		
				// }
			}
		} else {									// new user
			history[_id] = entry(now, _amount, 0);
			if (!_recipient.send(_amount)) throw;
			Sent(_amount, _recipient, _id);
		}

		// uint gasUsed = msg.gas - gasStart;
		// Debug(gasUsed, tx.gasprice);
		// if (!faucet.send(gasUsed * tx.gasprice)) throw;
	}

	function setEnabled(bool state) private ownerOnly {
		enabled = state;
		StatusChanged(enabled);
	}

	function withdraw () ownerOnly {
		if (!owner.send(this.balance)) throw;
		setEnabled(false);
	}

	function () payable { 
		Donation(msg.sender, msg.value);
	} 
}
