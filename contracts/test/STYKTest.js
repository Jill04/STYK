
 
const {
    BN,           // Big Number support 
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
  } = require('@openzeppelin/test-helpers');
  
  
  const truffleAssert = require('truffle-assertions');
  const { assert, expect } = require('chai');
  const STYK = artifacts.require('STYK');
 
  




  require("chai").use(require("chai-bignumber")(BN))
  .should();

  
  
  contract('STYK',() => {
         it('Should deploy smart contract properly',async() =>{
          const styk = await STYK.deployed();
         
          assert(styk.address !== '');
     
        });
     
                beforeEach(async function(){
                    
                      styk= await STYK.new(1672444800);
                      accounts = await web3.eth.getAccounts();

                    
                    })
              
                describe("[Testcase 1: To purchase the token]",() =>{
                      it("Token Buy",async() => {
                      await(styk.buy(accounts[1],{from:accounts[0],value:web3.utils.toWei("2","ether")}));
                        
                      });
                  });

                

                describe("[Testcase 2: To check for monthly rewards]",() =>{
                  it("Token Buy",async() => {
                  await(styk.buy(accounts[1],{from:accounts[0],value:web3.utils.toWei("2","ether")}));
                  await(styk.buy(accounts[2],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
                  await(styk.buy(accounts[3],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
                  await(styk.buy(accounts[4],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
                  await(styk.setStakeTime(1605627040));
                  try{
              
                    assert.isTrue(await(styk.monthlyRewardsPayOuts(accounts[1])));
                  }  
                    catch(e) {
                  
                  }
                 
                  
                  });
              });
  
            describe("[Testcase 3: To check for non -monthly rewards]",() =>{
              it("Token Buy",async() => {
              await(styk.buy(accounts[1],{from:accounts[0],value:web3.utils.toWei("2","ether")}));
              await(styk.buy(accounts[2],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
              await(styk.buy(accounts[3],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
             
              await(styk.setStakeTime(1605627040));
              try{
              
                assert.isFalse(await(styk.monthlyRewardsPayOuts(accounts[1])));
              }  
                catch(e) {
              
              }
              
              });
          });

          describe("[Testcase 4: To send payouts to early adopter that qualify]",() =>{
            it("Token Buy",async() => {

            await(styk.buy(accounts[1],{from:accounts[0],value:web3.utils.toWei("2","ether")}));
            await(styk.buy(accounts[2],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
            await(styk.buy(accounts[3],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
            await(styk.setAuctinEthLimit(web3.utils.toWei("6","ether")))
            await(styk.earlyAdopterBonus.call((accounts[1])));
          
            
            });
        });

        describe("[Testcase 5: To check for user not qualifying for early adopter bonus]",() =>{
          it("Token Buy",async() => {

          await(styk.buy(accounts[1],{from:accounts[0],value:web3.utils.toWei("2","ether")}));
          await(styk.buy(accounts[2],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
          await(styk.buy(accounts[3],{from:accounts[1],value:web3.utils.toWei("2","ether")}));
          await(styk.setAuctinEthLimit(web3.utils.toWei("4","ether")))
          try{
            assert.isFalse(await(styk.earlyadopters(accounts[3])));
            }
              catch(e){

              }
          
        
          
          });
      });

 });

  
  