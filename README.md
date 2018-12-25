# NOT FINISHED!!!

#Process

1) Create SmartBank
2) Create ISmartBank for SmartFund
3) Add SmartBank to Factory
4) Add ISmartBank to smartFund
5) Bind SmartBank with SmartFund
6) Bind SmartFund with SmartBank
7) Removed approve and transferFrom concept, now fund can send assets directly from Bank
8) Remove back param destAddress/fix bugs
9) Now fund can trade through bank pass exchange in param, trade function in bank more abstract.
10) Fixed Rebalance for Bank
11) Create bind bank with fund and fund with bank without functions, just in Factory.
12) Check balance calculation in ALL functions in fund from fund balance to bank balance.

#Next
1) Add windraw assets methods to bank.
2) remove unnecessary from smart fund
3) Test rebalance with several deposit at the same time
4) Calculate fund Profit not ONLY in ETH, because we do rebalance!!! Translate tokens in the rate of ETH and then do the calculations


#TODO
1) Add two factory functions Create Smart Fund for already existing Bank and Create SmartFund With Bank
2) ADD EVENTs like fund set in bank, fund change in bank ect.
3) ADD additional modifiers
4) Refactoring

#TODO TEST
1) OnlyFund and OnlyOwner permissions
2) Change SmartFund in SmartBank
3) Change SmartBank in SmartFund
4) events
5) Max tokens Rebalance (should work for 10 tokens)

#NOTE
1) Enable Solc Optimization for SmartFundRegistry
