import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

// To simplify the testing process and the specificity of the messages being sent, we decided to add clear default values in this transaction
message(0xf8a7ea5) TokenTransfer {
     queryId: Int as uint64; // should be 0
     amount: Int as coins; // should be amount of jettons to send
     destination: Address; // should be user address / TokenNotification.from
     responseDestination: Address?; // should be myAddress()
     customPayload: Cell?; // should be null
     forwardTonAmount: Int as coins; // should be ton("0.01")
     forwardPayload: Slice as remaining; // should be emptySlice()
}

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int;
  bAmount: Int;
  jettonAddressA: Address;
  jettonAddressB: Address;
  decimal: Int;

  init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address) {
    self.owner = admin;
    self.jettonAddressA = newJettonAddressA;
    self.jettonAddressB = newJettonAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {
  // start receive
  if (msg.amount > 0) {
    // amount to swap greater than 0
    if (sender() == self.owner) {
      // sender admin
      if (msg.from == self.jettonAddressA) {
        // add balance jetton a on pool
        self.aAmount = self.aAmount + msg.amount;
        // end add balance jetton a on pool
      }
      else if (msg.from == self.jettonAddressB) {
        // add balance jetton b on pool
        self.bAmount = self.bAmount + msg.amount;
        // end add balance jetton b on pool
      }
      else{
        // send back unknown jetton
        send(SendParameters{
          value: 0,
          to: sender(),
          bounce: true,
          mode: SendRemainingValue + SendIgnoreErrors,
          body: TokenTransfer{
            queryId : 0,
            amount: msg.amount,
            destination: sender(),
            responseDestination: context().sender,
            customPayload: null,
            forwardTonAmount: ton("0.01"),
            forwardPayload: emptySlice()
          }.toCell()
        });
        // end send back unknown jetton
      }
      // end sender admin
    }
    else{
      //sender not admin
      if (self.aAmount > 0 && self.bAmount > 0) {
        // ready to swap
        if (msg.from == self.jettonAddressA) {
          // swap from a
          if (msg.amount < self.aAmount) {
            // amount lower than pool
            let received : Int = ((self.bAmount * self.decimal)/self.aAmount) * (msg.amount * self.decimal);
            send(SendParameters{
            value: 0,
            to: sender(),
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: TokenTransfer{
              queryId : 0,
              amount: received,
              destination: sender(),
              responseDestination: context().sender,
              customPayload: null,
              forwardTonAmount: ton("0.01"),
              forwardPayload: emptySlice()
            }.toCell()
          });
          self.aAmount = self.aAmount + msg.amount;
          self.bAmount = self.bAmount - received;
          // end amount lower than pool
          }
          else {
            // amount greater than pool send back & throw error
            send(SendParameters{
            value: 0,
            to: sender(),
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: TokenTransfer{
              queryId : 0,
              amount: msg.amount,
              destination: sender(),
              responseDestination: context().sender,
              customPayload: null,
              forwardTonAmount: ton("0.01"),
              forwardPayload: emptySlice()
            }.toCell()
            });
            // end amount greater than pool send back & throw
          }
          // end swap from a
        }
        else if (msg.from == self.jettonAddressB) {
          // swap from b
          if (msg.amount < self.bAmount) {
            // amount lower than pool
            let received : Int = ((self.aAmount * self.decimal)/self.bAmount) * (msg.amount * self.decimal);
            send(SendParameters{
            value: 0,
            to: sender(),
            bounce: true,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: TokenTransfer{
              queryId : 0,
              amount: received,
              destination: sender(),
              responseDestination: context().sender,
              customPayload: null,
              forwardTonAmount: ton("0.01"),
              forwardPayload: emptySlice()
            }.toCell()
          });
          self.bAmount = self.bAmount + msg.amount;
          self.aAmount = self.aAmount - received;
          // end amount lower than pool
          }
          else{
          // amount greater than pool
          send(SendParameters{
          value: 0,
          to: sender(),
          bounce: true,
          mode: SendRemainingValue + SendIgnoreErrors,
          body: TokenTransfer{
            queryId : 0,
            amount: msg.amount,
            destination: sender(),
            responseDestination: context().sender,
            customPayload: null,
            forwardTonAmount: ton("0.01"),
            forwardPayload: emptySlice()
          }.toCell()
          });
          // end amount greater than pool
          }
        // end swap from b
        }
        else {
          // unknown jetton send back
          send(SendParameters{
          value: 0,
          to: sender(),
          bounce: true,
          mode: SendRemainingValue + SendIgnoreErrors,
          body: TokenTransfer{
            queryId : 0,
            amount: msg.amount,
            destination: sender(),
            responseDestination: context().sender,
            customPayload: null,
            forwardTonAmount: ton("0.01"),
            forwardPayload: emptySlice()
          }.toCell()
          });
          throw(100);
          // end unknown jetton send back
        }
          send(SendParameters{
          value: 0,
          to: sender(),
          bounce: true,
          mode: SendRemainingValue + SendIgnoreErrors,
          body: TokenTransfer{
            queryId : 0,
            amount: msg.amount,
            destination: sender(),
            responseDestination: context().sender,
            customPayload: null,
            forwardTonAmount: ton("0.01"),
            forwardPayload: emptySlice()
          }.toCell()
          });
          throw(100);
      // end ready to swap
      }  
    //end sender not admin
    }
  // end amount swap greater than 0
  throw(100);
  }
  // end receive
}
  
  get fun price(jetton: Address): Int { 
    if (jetton == self.jettonAddressA) {
      return(self.aAmount * self.decimal / self.bAmount);
    } 
    else if (jetton == self.jettonAddressB) {
      return(self.bAmount * self.decimal / self.aAmount);
    }
    else {
      return 0;
    }
  }
  
  get fun balance(jetton: Address): Int { 
    if (jetton == self.jettonAddressA) {
      return self.aAmount;
    }
    else if (jetton == self.jettonAddressB) {
      return self.bAmount;
    }
    else{
      return 0;
    }
  }
}
