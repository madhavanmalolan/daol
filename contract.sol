//work in progress
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/ownership/Ownable.sol";




import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GovernanceToken is ERC20, Ownable {
    constructor() ERC20("GovernanceToken", "GOV") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}



contract DAOLGovernance {
    using SafeMath for uint256;

    // Token contract
    GovernanceToken public governanceToken;
    // Bonding curve parameters
    uint256 public constant BONDING_CURVE_PRECISION = 1e18;
    uint256 public constant SELL_PREMIUM = 10; // 10% premium on selling tokens to bonding curve
    // State variables
    uint256 public totalSupply;
    uint256 public bondingCurveCoefficient;
    uint256 public nextRequestId;

    uint256 QUORUM_DENOMINATOR = 3;
    uint256 PASSING_DENOMINATOR = 2;

    constructor() {
        governanceToken = new GovernanceToken();
        totalSupply = 0;
        bondingCurveCoefficient = 1e18;
        nextRequestId = 1;
    }

    // Buy tokens from bonding curve
    function buyTokens() external payable {
        uint256 tokensToMint = calculateTokensToMint(msg.value);
        totalSupply = totalSupply.add(tokensToMint);
        governanceToken.mint(msg.sender, tokensToMint);
        emit TokensBought(msg.sender, tokensToMint);
    }

    // Sell tokens to bonding curve
    function sellTokens(uint256 amount) external {
        uint256 ethToReturn = calculateEthToReturn(amount);
        uint256 premium = ethToReturn.mul(SELL_PREMIUM).div(100);
        uint256 finalReturn = ethToReturn.sub(premium);

        totalSupply = totalSupply.sub(amount);
        governanceToken.burnFrom(msg.sender, amount);
        payable(msg.sender).transfer(finalReturn);
        emit TokensSold(msg.sender, amount);
    }

    // Hosting request structure
    struct HostingRequest {
        address submitter;
        string gitRepoLink;
        string hostedServiceURL;
        uint256 votes;
        bool approved;
    }

    // State variables
    uint256 public nextRequestId;
    mapping(uint256 => HostingRequest) public hostingRequests;
    mapping(uint256 => mapping(address => bool)) public votesCast;

    // Events
    event HostingRequestSubmitted(uint256 indexed requestId, address indexed submitter, string gitRepoLink, string hostedServiceURL);
    event HostingRequestVoted(uint256 indexed requestId, address indexed voter, bool approval);

    constructor(IERC20 _governanceToken) {
        governanceToken = _governanceToken;
        nextRequestId = 1;
    }

    // Submit a hosting request
    function submitHostingRequest(string calldata gitRepoLink, string calldata hostedServiceURL) external {
        hostingRequests[nextRequestId] = HostingRequest({
            submitter: msg.sender,
            gitRepoLink: gitRepoLink,
            hostedServiceURL: hostedServiceURL,
            votes: 0,
            approved: false
        });
        emit HostingRequestSubmitted(nextRequestId, msg.sender, gitRepoLink, hostedServiceURL);
        nextRequestId++;
    }

    // Vote on a hosting request
    function voteOnHostingRequest(uint256 requestId, bool approve) external {
        require(!votesCast[requestId][msg.sender], "Already voted on this request");
        uint256 voterBalance = governanceToken.balanceOf(msg.sender);

        if (approve) {
            hostingRequests[requestId].votes = hostingRequests[requestId].votes.add(voterBalance);
        }

        votesCast[requestId][msg.sender] = true;
        emit HostingRequestVoted(requestId, msg.sender, approve);
    }

    function quorumReached(uint256 requestId) public view returns (bool) {
        uint256 totalVotes = hostingRequests[requestId].votes;
        uint256 quorum = totalSupply.div(QUORUM_DENOMINATOR);
        return totalVotes >= quorum;
    }

    function isRequestPassed(uint256 requestId) public view returns (bool) {
        return quorumReached(requestId) && hostingRequests[requestId].votes > totalSupply.div(PASSING_DENOMINATOR);
    }
}
