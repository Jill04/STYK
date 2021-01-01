
 
const {
    BN,           // Big Number support 
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
  } = require('@openzeppelin/test-helpers');
  
  
  const truffleAssert = require('truffle-assertions');
  const { assert, expect } = require('chai');
  const STYK = artifacts.require('STYK_I');
 
  const denominator = new BN(10).pow(new BN(15));
  
  const getWith15Decimals = function (amount) {
      return new BN(amount).mul(denominator);
    };
  




  require("chai").use(require("chai-bignumber")(BN))
  .should();

  
  
  contract('STYK',() => {
         it('Should deploy smart contract properly',async() =>{
          const styk = await STYK.deployed();
         
          assert(styk.address !== '');
     
        });
     
                beforeEach(async function(){
                    
                      styk= await STYK.new(4765046400,1612051200,web3.utils.toWei("10000000000000000000000","ether"));
                      accounts = await web3.eth.getAccounts();                     
                    
                    })
              
               describe("[Testcase 1: To purchase the token]",() =>{
                      it("Token Buy",async() => {
                      await(styk.buy(accounts[1],{from:accounts[0],value:web3.utils.toWei("2","ether")}));
                        
                      });
                  });

                

                describe("[Testcase 2: To sell tokens]",() =>{
                  it("Token Buy",async() => {
                  await(styk.buy(accounts[0],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
                  await(styk.buy(accounts[1],{from:accounts[2],value:web3.utils.toWei("2","ether")}));
                  await(styk.buy(accounts[1],{from:accounts[3],value:web3.utils.toWei("2","ether")}));
                  await(styk.buy(accounts[1],{from:accounts[4],value:web3.utils.toWei("2","ether")}));
                 
                 
                  
                  
                  await(styk.sell(getWith15Decimals(9),{from:accounts[2]}));
                
                 
                  
                  });
              });
  
              describe("[Testcase 3: To re-inevest]",() =>{
                it("Token Buy",async() => {
                await(styk.buy(accounts[0],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
                await(styk.buy(accounts[1],{from:accounts[2],value:web3.utils.toWei("2","ether")}));
                await(styk.buy(accounts[1],{from:accounts[4],value:web3.utils.toWei("2","ether")}));
               
                await(styk.reinvest({from:accounts[2]}));
              
               
                
                });
            });

            describe("[Testcase 4: To withdraw tokens]",() =>{
              it("Token Buy",async() => {

              await(styk.buy(accounts[0],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
              await(styk.buy(accounts[1],{from:accounts[2],value:web3.utils.toWei("2","ether")}));
              await(styk.buy(accounts[1],{from:accounts[3],value:web3.utils.toWei("2","ether")}));
            
              await(styk.withdraw({from:accounts[3]}));
            
              
              });
          });

         

 });

  
  
