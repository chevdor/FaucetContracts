pragma solidity ^0.4.6;

/**
 * Standard 'owned' contract.
 */
contract owned {
	address owner;
	function owned() {
		owner = msg.sender;
	}

	modifier ownerOnly (){
		if (msg.sender != owner) throw;
		_;
	}
}

/**
 * An helpful contract for faucets and refunds.
 */
contract FaucetSend is owned{
	uint public VERSION = 2;

	mapping (address => uint) public contribs;
	mapping (address => bool) public whitelist;

	uint public total;

	function FaucetSend() {
		total = 0 wei;
		whitelist[msg.sender] = true;
	}

	event Sent(address from, address to, string message);

	function setWhiteList(address addr, bool state) ownerOnly {
		if (state)
			whitelist[addr] = state;
		else
			delete whitelist[addr];
	}

	/**
	 * Send equal payments to each of the address provided as input.
	 */
	function send(address[] recipients, string message) payable {
		for (uint i=0; i < recipients.length; i++) {
			address recipient = recipients[i]; 
			bool res;
			if (recipient != msg.sender) {	
				res = recipient.send(msg.value/recipients.length);
				Sent(msg.sender, recipient, message);
			}
		}
		contribs[msg.sender] += msg.value;
		total += msg.value;
	}

	/**
	 * Users who do no longer need their test ETH can send it back
	 * to the faucet.
	 */
	function () payable {}

	/**
	 * If funds remain into the faucet, the owner
	 * can send the funds to himself.
	 */
	function withdrawAll() ownerOnly {
		if(!owner.send(this.balance)) throw;
	}

	modifier whitelistOnly () {
		if (!whitelist[msg.sender]) throw;
		_;
	}

	modifier contribOnly () {
		if (contribs[msg.sender] <= 0) throw;
		_;
	}
	/**
	 * When users send back funds to the faucet,
	 * whitelisted contribs can get back a part of it depending on
	 * how big was their contrib.
	 */
	function withdraw() whitelistOnly contribOnly {
		uint amount = this.balance * contribs[msg.sender] / total;
		if (!msg.sender.send(amount)) throw;
		contribs[msg.sender] = 0;
		total -= amount;
	}
}