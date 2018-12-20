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

#Next
1) Change balance calculation from fund to bank.
2) Add windraw assets methods to bank.
3) Test rebalance with new tradeFromBank
4) Test rebalance with several deposit at the same time


#TODO
1) Add two factory functions Create Smart Fund for already existing Bank and Create SmartFund With Bank
2) ADD EVENTs like fund set in bank, fund change in bank ect.
3) ADD additional modifiers
4) Change balance calculation in ALL functions in fund from fund balance to bank balance!!!
5) Create bind bank with fund without functions, just in Factory!!!

#Thoughts
1) trade in bank should be write as abstract param, so fund pass trade as param to bank contract execute trade function, and bank just executes a transaction with bank balance, all logic is written in fund, all logic can be change, bank independent of logic

2) do same abstract things with rebalance to avoid extra transactions

3) maybe if we do full abstract we can remove param destAddress
