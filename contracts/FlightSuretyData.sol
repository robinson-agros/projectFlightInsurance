//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false


  // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 1;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 2;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 3;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 4;
    uint8 private constant STATUS_CODE_LATE_OTHER = 5;

    struct Airline {
        string name;
        bool isRegistered;
        bool hasFunds;
    }

    mapping (address => Airline) private Airlines;
    address[] airlinesRegister = new address[](0);

    mapping (address => uint8) private approvedCallers;    

    // Flights
    struct Flight {
        bool isRegistered;
        uint8 statusCode; // 0: unknown (in-flight), >0: landed
        uint256 updatedTimestamp;
        address airline;
        string flight;
        string from;
        string to;
    }
    mapping(bytes32 => Flight) private flights;

    // Insurances
    struct Insurance {        
        uint256 amount; // Passenger insurance payment
        uint256 multiplier; // General damages multiplier (1.5x by default)
        bool isFunded;
        bool isCredited;
    }

    mapping (bytes32 => mapping (address => Insurance)) insuredPassengersPerFlight;
    mapping (bytes32 => address[]) listofInsurees;

    mapping (address => uint) public pendingPayments;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor                (
                                    address airlineAddress, 
                                    string memory airlineName
                                )                             
    {
        contractOwner = msg.sender;
        Airlines[airlineAddress] = Airline({name: airlineName, isRegistered:true, hasFunds:false});
        airlinesRegister.push(airlineAddress);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that contractOwnereds to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirline(address caller){
        Airlines[caller].isRegistered == true;
        _;
    }

    modifier requireFunds(address addr){
        require(Airlines[addr].hasFunds == true, "Airline not funded");
        _;
    }

    modifier requireRegisteredCaller() {
        require(approvedCallers[msg.sender] == 1, "Address is not approve to call this function");
        _;
    }

    /********************************************************************************************/
    /*                                           EVENTS                                         */
    /********************************************************************************************/
    event AirlineRegistered(string name, address addr);
    event AirlineFunded(string name, address addr);
    event FlightRegistered(address airline, string flightName, string from, string to, uint256 timestamp);
    event Received(address, uint);
    event InsureeCredited(address passenger, uint256 amount);
    event AccountWithdrawn(address passenger, uint256 amount);
    event FlightStatusUpdated(address airline, string flight, uint256 timestamp, uint8 statusCode);

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function isRegistered(address airline) public view returns(bool){
        return Airlines[airline].isRegistered;
    }

    function numberAirlines() public view returns(uint256){
        return airlinesRegister.length;
    }

    function isFunded(address airline) public view returns(bool){
        return Airlines[airline].hasFunds;  
    }

    function getRegisteredAirlines() external view returns(address[] memory) {
        return airlinesRegister;
    }

    function isFlightRegistered(address airline, string calldata flight, uint timestamp) external view returns(bool){
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return flights[flightKey].isRegistered;
    }

    function isInsured(address airline, string calldata flight, uint timestamp, address passenger) external view returns(bool){
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return insuredPassengersPerFlight[flightKey][passenger].isFunded;
    }

    function authorizeCaller(address addr) external requireContractOwner returns(bool) {
        approvedCallers[addr] = 1;
        return true;
    }

    function getPendingPayments(address addr) external view returns(uint) {
        return pendingPayments[addr];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   

    function registerAirline(address newAddress, string calldata airlineName) external requireIsOperational requireRegisteredCaller {
        require(!Airlines[newAddress].isRegistered, "Airline already registered");
        Airlines[newAddress] = Airline({name: airlineName, isRegistered:true, hasFunds:false});
        airlinesRegister.push(newAddress);
        emit AirlineRegistered(airlineName, newAddress); 
    }
    // }

    /**
    * @dev Register a list of flights allowed to track,     
    *       and buy an insurance for it.
    *
    */  

    function registerFlight(address airline, string calldata flight, string calldata from, string calldata to, uint256 timestamp) external requireIsOperational requireRegisteredCaller {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(!flights[flightKey].isRegistered, "Flight previously registered");
        flights[flightKey] = Flight({
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: timestamp,
            airline: airline,
            flight: flight,
            from: from,
            to: to
        });

        emit FlightRegistered(airline, flight, from, to, timestamp);
    }

   /**
   * @dev Process flights
   */
  function processFlightStatus(address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external requireIsOperational requireRegisteredCaller {
    //require(!this.isLandedFlight(airline, flight, timestamp), "Flight already landed");

    bytes32 flightKey = getFlightKey(airline, flight, timestamp);    
    
    if (flights[flightKey].statusCode == STATUS_CODE_UNKNOWN) {
      flights[flightKey].statusCode = statusCode;
      if(statusCode == STATUS_CODE_LATE_AIRLINE) {
        creditInsurees(airline, flight, timestamp);
      }
    }

    emit FlightStatusUpdated(airline, flight, timestamp, statusCode);
  }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(   address airline,
                    string calldata flight,
                    address passenger,
                    uint256 amount,
                    uint256 timestamp
                            )
                            external
                            payable
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        insuredPassengersPerFlight[flightKey][passenger] = Insurance({            
            amount: amount,
            multiplier: 150,
            isFunded: true,
            isCredited: false
        });
        listofInsurees[flightKey].push(passenger);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees (address airline, string memory flight, uint256 timestamp) internal requireIsOperational requireRegisteredCaller{
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        for (uint i = 0; i < listofInsurees[flightKey].length; i++ ){
            Insurance memory insurance = insuredPassengersPerFlight[flightKey][listofInsurees[flightKey][i]];
            if (insurance.isCredited == false){
                insurance.isCredited = true;
                uint256 amount = (insurance.amount * insurance.multiplier) / 100;
                pendingPayments[listofInsurees[flightKey][i]] += amount;

                emit InsureeCredited(listofInsurees[flightKey][i], amount);
            }
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address passenger) external requireIsOperational requireRegisteredCaller{
        //require(passenger == tx.origin, "Just Insuree could call this function" );
        require(pendingPayments[passenger] > 0, "Currently there's no funds to withdraw");

        uint256 amount = pendingPayments[passenger];
        pendingPayments[passenger] = 0;

        payable(address(uint160(passenger))).transfer(amount);

        emit AccountWithdrawn(passenger, amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address airline) public requireIsOperational {        
        Airlines[airline].hasFunds = true;
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */

    

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

}