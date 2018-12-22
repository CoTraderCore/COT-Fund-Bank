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

#Next
1) Add windraw assets methods to bank.
2) remove unnecessary from smart fund
3) Test rebalance with several deposit at the same time
4) Check balance calculation in ALL functions in fund from fund balance to bank balance!!!


#TODO
1) Add two factory functions Create Smart Fund for already existing Bank and Create SmartFund With Bank
2) ADD EVENTs like fund set in bank, fund change in bank ect.
3) ADD additional modifiers
4) Create bind bank with fund without functions, just in Factory!!!
5) Refactoring

#NOTE
1) Enable Solc Optimization for SmartFundRegistry
