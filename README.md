# NOT FINISHED!!!

#Done

1) Create SmartBank
2) Create ISmartBank for SmartFund
3) Add SmartBank to Factory
4) Add ISmartBank to smartFund
5) Bind SmartBank with SmartFund
6) Bind SmartFund with SmartBank
7) Removed approve and transferFrom concept, now fund can send assets directly from Bank
8) Change trade destination to BANK
9) Change rebalance destination to BANK (also add change to rebalance send remaining ETH to bank)

#Next
1) Change trade sender from SmartFund to SmartBank or set trade function in bank?
2) if set trade in bank, set Interface for trade to fund.
3) Add windraw assets methods to bank.


#TODO
1) Add two factory functions Create Smart Fund for already existing Bank and Create SmartFund With Bank
2) ADD EVENTs like fund set in bank, fund change in bank ect.
3) ADD additional modifiers
4) Change balance calculation in ALL functions in fund from fund balance to bank balance!!!
5) Create bind bank with fund without functions, just in Factory!!!


#Possible versions bugs
1) We need add param destAddress in trade function, for change dest from fund to bank for now this param hardcode to this. So can be some frontend issue.

#Thoughts
1) trade in bank should be write as abstract param, so fund pass trade as param to bank contract execute trade function, and bank just executes a transaction with bank balance, all logic is written in fund, all logic can be change, bank independent of logic

2) do same abstract things with rebalance to avoid extra transactions

3) maybe if we do full abstract we can remove param destAddress
