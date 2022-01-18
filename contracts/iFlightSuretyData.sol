//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
 *@dev External interface to interact with Data Contract based on Proxie Strategy
*/

interface IFlightSuretyData {
    struct Airline {
        string name;
        bool isRegistered;
        bool hasFunds;
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode; // 0: unknown (in-flight), >0: landed
        uint256 updatedTimestamp;
        address airline;
        string flight;
        string from;
        string to;
    }

    struct Insurance {
        address passenger;
        uint256 amount; // Passenger insurance payment
        uint256 multiplier; // General damages multiplier (1.5x by default)
        bool isCredited;
    }

    /********************************************************************************************/
    /*                                           EVENTS                                         */
    /********************************************************************************************/
    event AirlineRegistered(string name, address addr);
    event AirlineFunded(string name, address addr);
    event FlightRegistered(address airline, string flightName, string from, string to, uint256 timestamp);

    function isOperational() external view returns(bool);
    function setOperatingStatus(bool mode) external;
    function isRegistered(address airline) external view returns(bool);
    function numberAirlines() external view returns(uint256);
    function getRequestBuffer(address airlineApplication) external view returns(address[] memory);
    function authorizeCaller(address addr) external returns(bool); 
    function getRegisteredAirlines() external view returns(address[] memory);
    function isFunded(address airline) external view returns(bool);
    function registerAirline(address newAddress, string calldata airlineName) external;
    function registerFlight(address airline, string calldata flight, string calldata from, string calldata to, uint256 timestamp) external;
    function fund(address addr) external;
    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure external returns(bytes32);
    function isFlightRegistered(address airline, string calldata flight, uint timestamp) external view returns(bool);
    function buy(address airline, string calldata flight, address passenger, uint256 amount, uint256 timestamp) external payable;
    function isInsured(address airline, string calldata flight, uint timestamp, address passenger) external view returns(bool);
    function creditInsurees (address airline, string memory flight, uint256 timestamp) external;
    function processFlightStatus(address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external;
    function pay(address passenger) external;
    function getPendingPayments(address addr) external view returns(uint);
}