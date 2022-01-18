var Test = require('../config/testConfig.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  it("Constructor", async () =>{
    let added = await config.flightSuretyData.isRegistered("0xf17f52151EbEF6C7334FAD080c5704D77216b732");
    assert.equal(added, true, "No airline added on construction");
  })

  it("Add 4 new Airlines", async () => {
    await config.flightSuretyApp.registerAirline(accounts[2], "LATAM", {from:accounts[1]});
    await config.flightSuretyApp.registerAirline(accounts[3], "LATAM", {from:accounts[1]});
    await config.flightSuretyApp.registerAirline(accounts[4], "LATAM", {from:accounts[1]});
    await config.flightSuretyApp.registerAirline(accounts[5], "LATAM", {from:accounts[1]});
    let added = await config.flightSuretyData.isRegistered(accounts[5]);
    assert.equal(added, true, "Airlines less than 5 added");
  })

  it("6 airline not added test", async () => {        
    await config.flightSuretyApp.registerAirline(accounts[6], "LATAM", {from:accounts[1]});
    let added = await config.flightSuretyData.isRegistered(accounts[6]);
    assert.equal(added, false, "This airline should not be added");
  })

  it("6 airline added test", async () => {        
    await config.flightSuretyApp.registerAirline(accounts[6], "LATAM", {from:accounts[2]});
    await config.flightSuretyApp.registerAirline(accounts[6], "LATAM", {from:accounts[3]});    
    let added = await config.flightSuretyData.isRegistered(accounts[6]);
    assert.equal(added, true, "This airline was not succesfully added");
  })
  
  it("Fund Airline -- should be funded", async() => {
    await config.flightSuretyApp.fundAirline(accounts[1],{from:accounts[1], value:10});
    let isFunded = await config.flightSuretyData.isFunded(accounts[1]);
    assert.equal(isFunded, true, "This airline should be funded");
  });

  it("Register Flight", async() => {
    await config.flightSuretyApp.registerFlight("LA358", "Peru", "Madrid", 1642258800, accounts[1], {from:accounts[1]});
    let isRegistered = await config.flightSuretyData.isFlightRegistered(accounts[1], "LA358", 1642258800);
    assert.equal(isRegistered, true, "Fligh is not Registered");
  })

  it("Buy Insurance", async() => {
    await config.flightSuretyApp.buyInsurance(accounts[1], "LA358", 1642258800, {from:accounts[7], value:100});
    let isRegistered = await config.flightSuretyData.isInsured(accounts[1], "LA358", 1642258800, accounts[7]);
    assert.equal(isRegistered, true, "Not succesfully insured");
  })

}
)