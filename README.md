# NOT FINISHED!!!

#Done

1) Create SmartBank
2) Create ISmartBank for SmartFund
3) Add SmartBank to Factory
4) Add ISmartBank to smartFund
5) Bind SmartBank with SmartFund
6) Bind SmartFund with SmartBank
7) Removed approve and transferFrom concept, now fund can send assets directly from Bank

#Next
1) Change trade destination to BANK
2) Change rebalance destination to BANK (also add change to rebalance send remaining ETH to bank)
3) Change trade sender from SmartFund to SmartBank
4) Add windraw assets methods to bank.

#TODO
1) Add two factory functions Create Smart Fund for already existing Bank and Create SmartFund With Bank
2) ADD EVENTs like fund set in bank, fund change in bank ect.
3) ADD additional modifiers
4) Change balance calculation in ALL functions in fund from fund balance to bank balance!!!
5) Create bind bank with fund without functions, just in Factory!!!


#Possible versions bugs
1) We need add param destAddress in trade function, for change dest from fund to bunk for now this param hardcode to this. So can be some frontend issue.
