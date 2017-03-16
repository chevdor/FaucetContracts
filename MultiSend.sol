pragma solidity ^0.4.6;

contract Multisend {
	uint public VERSION = 1;
	event Sent(address from, address to, string message);

	function Multisend() {}
	
	function send(address[] recipients, string message) payable {
		for (uint i=0; i< recipients.length; i++) {
			if (!recipients[i].send(msg.value/recipients.length)) throw;
			Sent(msg.sender, recipients[i], message);
		}
	}
}
