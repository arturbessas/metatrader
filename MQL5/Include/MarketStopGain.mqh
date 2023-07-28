//+------------------------------------------------------------------+
//|                                                     MarketStopGain.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
*/


class MarketStopGain: public Node
{	
	public:
	Context *context;
	double Distance;
	string Type;
		
	void on_trade(void);
	
	MarketStopGain(void);
	MarketStopGain(Context *cont, double distance, string type);
	~MarketStopGain(){};		
};

MarketStopGain::MarketStopGain(void){}

MarketStopGain::MarketStopGain(Context *cont, double distance, string type = "absolute")
{
	context = cont;
	Distance = distance;
	Type = type;
}

void MarketStopGain::on_trade(void)
{
	if(!context.pos_info.Select(context.stock_code))
		return;
		
	double signal = 1;
	
	if(context.pos_info.PositionType() == POSITION_TYPE_SELL)
		signal = -1;
	
	double avg_price = context.pos_info.PriceOpen();
	double current_price = context.current_price();
	
	double distance = Type == "absolute" ? Distance : (avg_price * Distance/100));
	
	if((current_price - avg_price) * signal > distance)
	{
		context.trade.PositionClose(context.stock_code);
	}
	
}