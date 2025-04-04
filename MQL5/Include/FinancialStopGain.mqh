//+------------------------------------------------------------------+
//|                                            FinancialStopGain.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


 /*
#include <Enums.mqh>
#include <Basic.mqh>
#include <Context.mqh>
#include <Trade\PositionInfo.mqh>
Context *context;
//*/

#include <Generic\HashSet.mqh>

class FinancialStopGain: public Node
{	
	public:	
		
	void on_trade(void);
	void on_order(MqlTradeTransaction &trans);
	
	FinancialStopGain(void);
	FinancialStopGain(double value, double multiplier);
	~FinancialStopGain(){};
	
	private:
	
	double Value;
	double Multiplier;
	int max_step;
	
	ulong all_positions[];
	double closed_profit;
	CHashSet<ulong> checked_deals;
};

FinancialStopGain::FinancialStopGain(void){}

FinancialStopGain::FinancialStopGain(double value, double multiplier)
{
	Value = value;
	Multiplier = multiplier;
	closed_profit = 0;
	max_step = 0;
}

void FinancialStopGain::on_order(MqlTradeTransaction &trans)
{
   if(HistoryDealSelect(trans.deal) && !checked_deals.Contains(trans.deal) && HistoryDealGetDouble(trans.deal, DEAL_PROFIT) != 0)
   {           
      closed_profit += HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP);
      
      checked_deals.Add(trans.deal);
   }
}

void FinancialStopGain::on_trade(void)
{
	if(!context.is_positioned())
	{
	   if(ArraySize(all_positions) > 0)
	      ArrayFree(all_positions);
	   if(checked_deals.Count() > 0)
	      checked_deals.Clear();	      
	   closed_profit = 0;
	   max_step = 0;
		return;
	}
			
	double current_profit = 0;
	
	int positions = context.positions_quantity();
	for(int i = 0; i < positions; i++)
	{
	   if(context.pos_info.SelectByTicket(context.position.positions[i]))
	      current_profit += context.pos_info.Profit() + context.pos_info.Swap();
	}
	
	if(positions - 1 > max_step)
	   max_step = positions - 1;
	   
	double total_profit = current_profit + closed_profit;
	
	if(total_profit >= Value * MathPow(Multiplier, max_step))
	{
		context.ClosePositions(StringFormat("Stop gain financeiro: %.2f", total_profit));
	}
	
}