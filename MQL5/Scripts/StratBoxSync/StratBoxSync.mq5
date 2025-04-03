#include <Trade/Trade.mqh>

class StratBoxClient
{
public:
    void NewPosition(ulong magic_number, ulong position_ticket)
    {
        Print("NewPosition called: Magic=", magic_number, " Ticket=", position_ticket);
    }

    void ClosePosition(ulong magic_number, ulong position_ticket)
    {
        Print("ClosePosition called: Magic=", magic_number, " Ticket=", position_ticket);
    }
};

StratBoxClient client;
ulong lastDealTicket = 0;

// Function to check new deals in history
void CheckDeals()
{
    int totalDeals = HistoryDealsTotal();
    if (totalDeals == 0)
        return;
    
    for (int i = totalDeals - 1; i >= 0; i--)
    {
        ulong deal_ticket = HistoryDealGetTicket(i);
        if (deal_ticket <= lastDealTicket)
            break;
        
        ulong order_ticket = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
        ulong position_ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
        ulong magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
        int type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
        
        if (type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL)
        {
            client.NewPosition(magic, position_ticket);
        }
        else if (type == DEAL_TYPE_BUY_CLOSED || type == DEAL_TYPE_SELL_CLOSED || type == DEAL_TYPE_SL || type == DEAL_TYPE_TP || type == DEAL_TYPE_STOPOUT)
        {
            client.ClosePosition(magic, position_ticket);
        }
        
        lastDealTicket = deal_ticket;
    }
}

// Main script entry point
void OnStart()
{
    lastDealTicket = HistoryDealGetTicket(HistoryDealsTotal() - 1);
    while (!IsStopped())
    {
        CheckDeals();
        Sleep(1000);
    }
}
