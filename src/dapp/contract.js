import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);        
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {

            this.owner = accts[0];
            this.firstAirline = accts[1];

            let counter = 1;

            while (this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while (this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }
            
            callback();
        });
        
    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner }, callback);        
    }

    registerAirline(airlineName, airlineAddress, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerAirline(airlineAddress, airlineName)
            .send({ from: self.owner, gas: 6721900 }, callback);
    }

    registerFlight(flightName, flightFrom, flightTo, flightTimestamp, airline,callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerFlight(flightName, flightFrom, flightTo, flightTimestamp, airline)
            .send({ from: self.owner, gas: 6721900 }, callback);
    }

    fundAirline(airlineAddress, callback) {
        let self = this;
        const fee = this.web3.utils.toWei('10', 'ether');
        self.flightSuretyApp.methods
            .fundAirline(airlineAddress)
            .send({ from: airlineAddress, value: fee }, callback);
    }

    isAirlineRegistered(airlineAddress, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isAirlineRegistered(airlineAddress)
            .call({ from: self.owner }, callback);
    }

    isAirlineFunded(airlineAddress, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isFunded(airlineAddress)
            .call({ from: self.owner }, callback);
    }

    buy(flightName, airlineAddress, timestamp, amount, callback) {
        let self = this;        
        self.flightSuretyApp.methods
            .buyInsurance(airlineAddress, flightName, timestamp)
            .send({ from: self.passengers[0], gas: 6721900, value: amount }, callback);
    }

    fetchFlightStatus(flightName, airlineAddress, timestamp, callback) {
        let self = this;
        let payload = {
            airline: airlineAddress,
            flight: flightName,
            timestamp: timestamp
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }

    getPassengerCredit(passangerAddress, callback) {
        let self = this;        
        self.flightSuretyApp.methods
            .getCreditPending(passangerAddress)
            .call({ from: self.owner }, callback);
    }

    withdrawCredit(pessangerAddress, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .pay(pessangerAddress)
            .send({ from: self.owner }, (error, result) => {
                callback(error, result);
            });
    }
}