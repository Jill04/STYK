pragma solidity ^0.6.0;

import "./SafeMath.sol";
import "./PriceConsumerV3.sol";

contract STYK is SafeMath,PriceConsumerV3{
    
    constructor(uint256 _lockTime,address _admin)public{
        
        // time lock for 100 years
        _lockTime =  safeAdd(now,_lockTime);
    
        STYK_REWARD_TOKENS = safeMul(200000,1e18);

        MONTHLY_REWARD_TOKENS = safeMul(100000,1e18);

        tokenBalanceLedger_[address(this)] = safeAdd(STYK_REWARD_TOKENS,MONTHLY_REWARD_TOKENS);

        tokenSupply_ = tokenBalanceLedger_[address(this)]; 

        administrators[keccak256(abi.encodePacked(_admin))] = true;
        ambassadors_[address(0)] = true;
        lockTime = _lockTime;
    }
    
     /*=================================
    =            MODIFIERS            =
    =================================*/
    // only people with tokens
    modifier onlybelievers () {
        require(myTokens() > 0);
        _;
    }
    
    // only people with profits
    modifier onlyhodler() {
        require(myDividends(true) > 0);
        _;
    }
    
    // administrators can:
    // -> change the name of the contract
    // -> change the name of the token
    // -> change the PoS difficulty 
    // they CANNOT:
    // -> take funds
    // -> disable withdrawals
    // -> kill the contract
    // -> change the price of tokens
    modifier onlyAdministrator(){
        address _customerAddress = msg.sender;
        require(administrators[keccak256(abi.encodePacked(_customerAddress))]);
        _;
    }
    
    
    modifier antiEarlyWhale(uint256 _amountOfEthereum){
        address _customerAddress = msg.sender;
        
      
        if( onlyAmbassadors && ((totalEthereumBalance() - _amountOfEthereum) <= ambassadorQuota_ )){
            require(
                // is the customer in the ambassador list?
                ambassadors_[_customerAddress] == true &&
                
                // does the customer purchase exceed the max ambassador quota?
                (ambassadorAccumulatedQuota_[_customerAddress] + _amountOfEthereum) <= ambassadorMaxPurchase_
                
            );
            
            // updated the accumulated quota    
            ambassadorAccumulatedQuota_[_customerAddress] = safeAdd(ambassadorAccumulatedQuota_[_customerAddress], _amountOfEthereum);
        
            // execute
            _;
        } else {
            // in case the ether count drops low, the ambassador phase won't reinitiate
            onlyAmbassadors = false;
            _;    
        }
        
    }
    
    
    /*==============================
    =            EVENTS            =
    ==============================*/
    event onTokenPurchase(
        address indexed customerAddress,
        uint256 incomingEthereum,
        uint256 tokensMinted,
        address indexed referredBy
    );
    
    event onTokenSell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 ethereumEarned
    );
    
    event onReinvestment(
        address indexed customerAddress,
        uint256 ethereumReinvested,
        uint256 tokensMinted
    );
    
    event onWithdraw(
        address indexed customerAddress,
        uint256 ethereumWithdrawn
    );
    
    // ERC20
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokens
    );
    
   
   
    
    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/
    string public name = "STYK";
    string public symbol = "STYK";
    uint256 constant public decimals = 18;
    uint8 constant internal dividendFee_ = 10;
    uint256 constant internal tokenPriceInitial_ = 0.0000001 ether;
    uint256 constant internal tokenPriceIncremental_ = 0.00000001 ether;
    uint256 constant internal magnitude = 2**64;
    uint256 STYK_REWARD_TOKENS  ;
    
    uint256 MONTHLY_REWARD_TOKENS;
    uint256 staketime;
   
    uint256 public lockTime;
    uint256 inflationTime = 0;
    
    // proof of stake (defaults at 1 token)
    uint256 public stakingRequirement = 1e18;
    
    // ambassador program
    mapping(address => bool) internal ambassadors_;
    uint256 constant internal ambassadorMaxPurchase_ = 1 ether;
    uint256 constant internal ambassadorQuota_ = 1 ether;
    
    
    
   /*================================
    =            DATASETS            =
    ================================*/
    // amount of shares for each address (scaled number)
    mapping(address => uint256) public tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;
    mapping(address => uint256) internal ambassadorAccumulatedQuota_;
    mapping(address => bool)  public rewardQualifier ;
    mapping(address => uint256)public stykRewards;
    mapping(address => address[])public referralUsers;
    mapping(address => mapping(address => bool))public userExists;
    mapping(address => bool)public earlyadopters;
    uint256 internal tokenSupply_ = 0;
    uint256 internal auctionEthDeposited = 0 ;
    uint256 internal auctionLimit = safeMul(10000,1e18);
    uint256 internal profitPerShare_;
    
    
    // administrator list (see above on what they can do)
    mapping(bytes32 => bool) public administrators;
    
    
    bool public onlyAmbassadors = false;
    

    /**
     * Converts all incoming Ethereum to tokens for the caller, and passes down the referral address (if any)
     */
    function buy(address _referredBy)
        public
        payable
        returns(uint256)
    {
        purchaseTokens(msg.value, _referredBy);
    }
    
    
    fallback()
        payable
        external
    {
        purchaseTokens(msg.value, address(0));
    }
    
    /**
     * Converts all of caller's dividends to tokens.
     */
    function reinvest()
        onlyhodler()
        public
    {
        // fetch dividends
        uint256 _dividends = myDividends(false); // retrieve ref. bonus later in the code
        
        // pay out the dividends virtually
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        
        // retrieve ref. bonus
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;
        
        // dispatch a buy order with the virtualized "withdrawn dividends"
        uint256 _tokens = purchaseTokens(_dividends, address(0));
        
        // fire event
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }
    
    /**
     * Alias of sell() and withdraw().
     */
    function exit()
        public
    {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if(_tokens > 0) sell(_tokens);
        
        
        withdraw();
    }

    /**
     * Withdraws all of the callers earnings.
     */
    function withdraw()
        onlyhodler()
        public
    {
        // setup data
        address payable _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false); // get ref. bonus later in the code
        
        // update dividend tracker
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        
        // add ref. bonus
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;
        
        // delivery service
        _customerAddress.transfer(_dividends);
        
        // fire event
        onWithdraw(_customerAddress, _dividends);
    }
    
    /**
     * Liquifies tokens to ethereum.
     */
    function sell(uint256 _amountOfTokens)
        onlybelievers ()
        public
    {
      
        address _customerAddress = msg.sender;
       
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _ethereum = tokensToEthereum_(_tokens);
        uint256 _dividends = safeDiv(_ethereum, dividendFee_);
        uint256 _taxedEthereum = safeSub(_ethereum, _dividends);
        
        // burn the sold tokens
        tokenSupply_ = safeSub(tokenSupply_, _tokens);
        tokenBalanceLedger_[_customerAddress] = safeSub(tokenBalanceLedger_[_customerAddress], _tokens);
        
        // update dividends tracker
        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedEthereum * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;       
        
        // dividing by zero is a bad idea
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            profitPerShare_ = safeAdd(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        }
        
        // fire event
        onTokenSell(_customerAddress, _tokens, _taxedEthereum);
    }
    
    
    /**
     * Transfer tokens from the caller to a new holder.
     * Remember, there's a 10% fee here as well.
     */
    function transfer(address _toAddress, uint256 _amountOfTokens)
        onlybelievers ()
        public
        returns(bool)
    {
        // setup
        address _customerAddress = msg.sender;
        
        // make sure we have the requested tokens
     
        require(!onlyAmbassadors && _amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        
        // withdraw all outstanding dividends first
        if(myDividends(true) > 0) withdraw();
        
        // liquify 10% of the tokens that are transfered
        // these are dispersed to shareholders
        uint256 _tokenFee = safeDiv(_amountOfTokens, dividendFee_);
        uint256 _taxedTokens = safeSub(_amountOfTokens, _tokenFee);
        uint256 _dividends = tokensToEthereum_(_tokenFee);
  
        // burn the fee tokens
        tokenSupply_ = safeSub(tokenSupply_, _tokenFee);

        // exchange tokens
        tokenBalanceLedger_[_customerAddress] = safeSub(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        tokenBalanceLedger_[_toAddress] = safeAdd(tokenBalanceLedger_[_toAddress], _taxedTokens);
        
        // update dividend trackers
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);
        
        // disperse dividends among holders
        profitPerShare_ = safeAdd(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        
        // fire event
        Transfer(_customerAddress, _toAddress, _taxedTokens);
        
        // ERC20
        return true;
       
    }
    
    /*----------  ADMINISTRATOR ONLY FUNCTIONS  ----------*/
    /**
     * administrator can manually disable the ambassador phase.
     */
    function disableInitialStage()
        onlyAdministrator()
        public
    {
        onlyAmbassadors = false;
    }
    
   
    function setAdministrator(bytes32 _identifier, bool _status)
        onlyAdministrator()
        public
    {
        administrators[_identifier] = _status;
    }
    
   
    function setStakingRequirement(uint256 _amountOfTokens)
        onlyAdministrator()
        public
    {
        stakingRequirement = _amountOfTokens;
    }
    
    
    function setName(string memory  _name)
        onlyAdministrator()
        public
    {
        name = _name;
    }
    
   
    function setSymbol(string memory _symbol)
        onlyAdministrator()
        public
    {
        symbol = _symbol;
    }

    
    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     * Method to view the current Ethereum stored in the contract
     * Example: totalEthereumBalance()
     */
    function totalEthereumBalance()
        public
        view
        returns(uint)
    {
        return address(this).balance;
    }
    
    /**
     * Retrieve the total token supply.
     */
    function totalSupply()
        public
        view
        returns(uint256)
    {
        return tokenSupply_;
    }
    
    /**
     * Retrieve the tokens owned by the caller.
     */
    function myTokens()
        public
        view
        returns(uint256)
    {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }
    
    /**
     * Retrieve the dividends owned by the caller.
       */ 
    function myDividends(bool _includeReferralBonus) 
        public 
        view 
        returns(uint256)
    {
        address _customerAddress = msg.sender;
        return _includeReferralBonus ? dividendsOf(_customerAddress) + referralBalance_[_customerAddress] : dividendsOf(_customerAddress) ;
    }
    
    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(address _customerAddress)
        view
        public
        returns(uint256)
    {
        return tokenBalanceLedger_[_customerAddress];
    }
    
    /**
     * Retrieve the dividend balance of any single address.
     */
    function dividendsOf(address _customerAddress)
        view
        public
        returns(uint256)
    {
        return (uint256) ((int256)(profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }
    
     /**
     * Retrieve the dividends from pre-minted tokens.
     */
    function dividendsOfPremintedTokens(uint256 _tokens)
        view
        public
        returns(uint256)
    {
        return (uint256) ((int256)(profitPerShare_ * _tokens)) - _tokens / magnitude;
    }
    
    /**
     * Return the buy price of 1 individual token.
     */
    function sellPrice() 
        public 
        view 
        returns(uint256)
    {
       
        if(tokenSupply_ == 0){
            return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends = safeDiv(_ethereum, dividendFee_  );
            uint256 _taxedEthereum = safeSub(_ethereum, _dividends);
            return _taxedEthereum;
        }
    }
    
    /**
     * Return the sell price of 1 individual token.
     */
    function buyPrice() 
        public 
        view 
        returns(uint256)
    {
        
        if(tokenSupply_ == 0){
            return tokenPriceInitial_ + tokenPriceIncremental_;
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends =safeDiv(_ethereum, dividendFee_  );
            uint256 _taxedEthereum = safeAdd(_ethereum, _dividends);
            return _taxedEthereum;
        }
    }
    
   
    function calculateTokensReceived(uint256 _ethereumToSpend) 
        public 
        view 
        returns(uint256)
    {
        uint256 _dividends = safeDiv(_ethereumToSpend, dividendFee_);
        uint256 _taxedEthereum = safeSub(_ethereumToSpend, _dividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        
        return _amountOfTokens;
    }
    
   
    function calculateEthereumReceived(uint256 _tokensToSell) 
        public 
        view 
        returns(uint256)
    {
        require(_tokensToSell <= tokenSupply_);
        uint256 _ethereum = tokensToEthereum_(_tokensToSell);
        uint256 _dividends = safeDiv(_ethereum, dividendFee_);
        uint256 _taxedEthereum = safeSub(_ethereum, _dividends);
        return _taxedEthereum;
    }
    
    
     /*==========================================
    =            Methods Developed By Minddeft    =
    ==========================================*/


        function _inflation() internal view returns(uint256){
            uint256 buyPrice_ = buyPrice();
            uint256 ethPrice =  safeMul(getLatestPrice(),1e10);
            uint256 inflation_factor = safeDiv(safeMul(buyPrice_,100),ethPrice);
            
            return inflation_factor;
        }
        
        // chainlink already give data as 10**8 so covnert to 18 decimal
        function checkInflation() external  returns(uint256){
            return _inflation();
        }
        
        //To calculate Inflation hours
        function calculateInfaltionHours()internal view returns (uint256)
        {
            return safeDiv(safeSub(now,inflationTime),3600);
        }
        
        
        //To calculate user's STYK rewards
        function _calculateSTYKReward(uint256 tokenAmount) internal view  returns(uint256){
           uint token_percent = safeDiv(safeMul(totalSupply(),100),tokenAmount);
           uint256 rewards = safeDiv(dividendsOfPremintedTokens(STYK_REWARD_TOKENS),token_percent);
           return rewards;
        }

        function calculateSTYKReward(uint256 tokenAmount) external view  returns(uint256){
            return _calculateSTYKReward(tokenAmount);
        }
        
        
        //To activate defaltion 
        function deflationSell() external {
            uint inflationHours = calculateInfaltionHours();
            require(inflationHours <= 72,"ERR_STAKE_HOURS_SHOULD_BE_LESS_THAN_72");
            require(!rewardQualifier[msg.sender],"ERR_REWARD_ALREADY_CLAIMED");
            uint256 userToken = safeDiv(safeMul(balanceOf(msg.sender),25),100);
            uint256 rewards = _calculateSTYKReward(balanceOf(msg.sender));
            stykRewards[msg.sender] = rewards;
            rewardQualifier[msg.sender] = true;
            sell(userToken);
        }
        
       
        //To pay STYK Rewards 
        function STYKRewardsPayOuts(address _to)external payable {
            
            require(rewardQualifier[_to] ,"ERR_NOT_QUALIFIED_FOR_REWARDS");
            uint256 _rewards = stykRewards[_to];
            uint256 rewardsInETH = tokensToEthereum_(safeDiv(_rewards,1e18));
           
            (bool success,) = (_to.call{value:rewardsInETH}(""));
            require(success,"ERR_PAYMENT_OF_REWARD_FAILED");
            stykRewards[_to] =  0;
            rewardQualifier[_to] = false;
            
        }
        
        
        //To calculate Month Payout Days
        function calculateMonthPayoutDays()internal view returns (uint256){
           
            uint currentday = safeAdd(safeDiv(safeSub(now,staketime),86400),1);
            uint daystoAdd = safeMul(safeSub(30,currentday),1 days);
            return safeAdd(now, daystoAdd);
        }
    
        //To aalculate team token holder percent
        function _teamTokenHolder(address _to)internal view returns (uint256){
            
            uint useractivecount = 0;
            uint usertotaltokens = 0;
          
            
            for(uint i = 0; i < referralUsers[_to].length ; i++){
                
                address _userAddress = referralUsers[_to][i];
                if(_checkUserActiveStatus(_userAddress)){
                  ++useractivecount;
                 }
            }
            
            if(useractivecount >= 3){
                for(uint i = 0; i<referralUsers[_to].length; i++){
                    address _addr =  referralUsers[_to][i];
                    usertotaltokens = safeAdd(balanceOf(_addr),usertotaltokens);
                }
               
                  return safeDiv(safeMul(totalSupply(),100),usertotaltokens);
               
            }
            else{
                  return 0;
            }
            
            
               
        }
        
        function teamTokenHolder(address _to)external view returns(uint256){
             return _teamTokenHolder(_to);
        }
        
        // To calculate monthly  rewards
        function _monthlyRewards(address _to)internal view returns(uint256){
                
             
                
                uint token_percent = _teamTokenHolder(_to);
                require(token_percent != 0,"ERR_YOU_DONT_QUALIFY_FOR_REWARDS");
                uint256 rewards = safeDiv(dividendsOfPremintedTokens(MONTHLY_REWARD_TOKENS),token_percent);
                
                return rewards; 
                
        }
        
         function monthlyRewards(address _to)external view returns(uint256){
               return  _monthlyRewards(_to);
                    
        }
        
        
        //To pay monthly rewards to the user
        function monthlyRewardsPayOuts(address _to)external payable {
            
               uint256 timer = calculateMonthPayoutDays();
               require(now > timer,"ERR_CANNOT_CLAIM_REWARDS_BEFORE_MONTH");
                uint256 rewards = _monthlyRewards(_to);
               
                uint256 rewardsInETH = tokensToEthereum_(safeDiv(rewards,1e18));
                (bool success,) = (_to.call{value:rewardsInETH}(""));
                require(success,"ERR_PAYMENT_OF_REWARD_FAILED");
            
        }   
           
            
         // To check the user's  status 
        function _checkUserActiveStatus(address _user)internal view  returns(bool){
                if(balanceOf(_user) > safeMul(10,1e18)){
                     return true;            
                }
                else{
                       
                    return false;
                }
        }
        
       //To distribute rewards to early adopters
        function earlyAdopterBonus(address _user)external payable{
         
          
           require(earlyadopters[_user],"ERR_NOT_AN_EARLY_ADOPTER_USER");  
           
           uint token_percent = safeDiv(safeMul(totalSupply(),100),balanceOf(_user));
           uint256 rewards = safeDiv(dividendsOfPremintedTokens(STYK_REWARD_TOKENS),token_percent);
           uint256 rewardsInETH = tokensToEthereum_(safeDiv(rewards,1e18));
           
           (bool success,) = (_user.call{value:rewardsInETH}(""));
           require(success,"ERR_PAYMENT_OF_REWARD_FAILED");
           earlyadopters[_user] = false;
        }
        
        
        //To add the early adopters
        function addEarlyAdopterUser(address _user,uint256 _amount)internal{
        
            if(!earlyadopters[_user]){
               earlyadopters[_user] = true ;  
            }
           
            auctionEthDeposited = safeAdd(auctionEthDeposited,_amount);
            
        }
        
            
        function setStakeTime(uint256 _timestamp)external  {
              staketime = _timestamp;
        }
        
     
        
    
    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/
    function purchaseTokens(uint256 _incomingEthereum, address _referredBy)
        antiEarlyWhale(_incomingEthereum)
        internal
        returns(uint256)
    {
        // data setup
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = safeDiv(_incomingEthereum, dividendFee_);
        uint256 _referralBonus = safeDiv(_undividedDividends, 3);
        uint256 _dividends = safeSub(_undividedDividends, _referralBonus);
        uint256 _taxedEthereum = safeSub(_incomingEthereum, _undividedDividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        uint256 _fee = _dividends * magnitude;
 
      
        require(_amountOfTokens > 0 && (safeAdd(_amountOfTokens,tokenSupply_) > tokenSupply_));
        
        // is the user referred by a karmalink?
        if(
            _referredBy != address(0) &&

            // no cheating!
            _referredBy != _customerAddress &&
            
        
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ){
            // wealth redistribution
            referralBalance_[_referredBy] = safeAdd(referralBalance_[_referredBy], _referralBonus);
        } else {
            // no ref purchase
            // add the referral bonus back to the global dividends cake
            _dividends = safeAdd(_dividends, _referralBonus);
            _fee = _dividends * magnitude;
        }
        
        // we can't give people infinite ethereum
        if(tokenSupply_ > 0){
            
            // add tokens to the pool
            tokenSupply_ = safeAdd(tokenSupply_, _amountOfTokens);
 
            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            profitPerShare_ += (_dividends * magnitude / (tokenSupply_));
            
            // calculate the amount of tokens the customer receives over his purchase 
            _fee = _fee - (_fee-(_amountOfTokens * (_dividends * magnitude / (tokenSupply_))));
        
        } else {
            // add tokens to the pool
            tokenSupply_ = _amountOfTokens;
        }
        
        // update circulating supply & the ledger address for the customer
        tokenBalanceLedger_[_customerAddress] = safeAdd(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        
       if(!userExists[_referredBy][msg.sender]){
           userExists[_referredBy][msg.sender] = true;
           referralUsers[_referredBy].push(msg.sender);
       }
       
        if(auctionEthDeposited <= auctionLimit  && safeAdd(auctionEthDeposited,_incomingEthereum) <= auctionLimit)
        {
        addEarlyAdopterUser(msg.sender,_incomingEthereum);
        
        }
        
        int256 _updatedPayouts = (int256) ((profitPerShare_ * _amountOfTokens) - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;
        
        // fire event
        emit onTokenPurchase(_customerAddress, _incomingEthereum, _amountOfTokens, _referredBy);
        
        return _amountOfTokens;
        
    }

    /**
     * Calculate Token price based on an amount of incoming ethereum
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function ethereumToTokens_(uint256 _ethereum)
        public
        view
        returns(uint256)
    {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 _tokensReceived = 
         (
            (
                // underflow attempts BTFO
                safeSub(
                    (sqrt
                        (
                            (_tokenPriceInitial**2)
                            +
                            (2*(tokenPriceIncremental_ * 1e18)*(_ethereum * 1e18))
                            +
                            (((tokenPriceIncremental_)**2)*(tokenSupply_**2))
                            +
                            (2*(tokenPriceIncremental_)*_tokenPriceInitial*tokenSupply_)
                        )
                    ), _tokenPriceInitial
                )
            )/(tokenPriceIncremental_)
        )-(tokenSupply_)
        ;
  
        return _tokensReceived;
    }
    
    /**
     * Calculate token sell value.
          */
     function tokensToEthereum_(uint256 _tokens)
        public
        view
        returns(uint256)
    {

        uint256 tokens_ = (_tokens + 1e18);
        uint256 _tokenSupply = (tokenSupply_ + 1e18);
        uint256 _etherReceived =
        (
            // underflow attempts BTFO
            safeSub(
                (
                    (
                        (
                            tokenPriceInitial_ +(tokenPriceIncremental_ * (_tokenSupply/1e18))
                        )-tokenPriceIncremental_
                    )*(tokens_ - 1e18)
                ),(tokenPriceIncremental_*((tokens_**2-tokens_)/1e18))/2
            )
        /1e18);
        return _etherReceived;
    }
    
    
    
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}


