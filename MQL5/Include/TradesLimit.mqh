//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


/*
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
*/


class TradesLimit: public Node
{	
	public:
	int limit;
	int current_quantity;
		
	void on_deal(Deal &deal);
	void on_daily_reset(void);
	
	TradesLimit(void);
	TradesLimit(int Limit);
	~TradesLimit(){};
};

TradesLimit::TradesLimit(void){}

TradesLimit::TradesLimit(int Limit)
{
	this.limit = Limit;
	this.current_quantity = 0;
}

void TradesLimit::on_deal(Deal &deal)
{	
	if(deal.volume > 0 && !context.is_positioned())
		this.current_quantity += 1;
	
	if(this.current_quantity >= this.limit)
		context.lock_the_day(StringFormat("Trades limit: %d >= %d", current_quantity, limit));
}

void TradesLimit::on_daily_reset(void)
{
	this.current_quantity = 0;
}