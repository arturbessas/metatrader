//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar
/*
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
#include <Trade\OrderInfo.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
COrderInfo order;
*/


class StopGain
{	
	public:
	double Distance;
	bool tp_sent;
	ulong tp_order;
		
	void on_order(MqlTradeTransaction &trans);
	
	StopGain(void);
	StopGain(double distance);
	~StopGain(){};		
};

StopGain::StopGain(void){}

StopGain::StopGain(double distance)
{
	Distance = distance;
	tp_sent = false;
}

void StopGain::on_order(MqlTradeTransaction &trans)
{
	if(trans.order_state != ORDER_STATE_FILLED)
		return;
		
	bool positioned = context.pos_info.Select(Symbol());
		
	if(positioned && !tp_sent)
	{
		double entry_price = context.pos_info.PriceOpen();
		
		if(context.pos_info.PositionType() == POSITION_TYPE_BUY)
			context.trade.SellLimit(context.pos_info.Volume(), context.round_price(entry_price + Distance), Symbol(), 0, 0, ORDER_TIME_GTC, 0, "Stop Gain na compra");
		else
			context.trade.BuyLimit(context.pos_info.Volume(), context.round_price(entry_price - Distance), Symbol(), 0, 0, ORDER_TIME_GTC, 0, "Stop Gain na venda");
		
		tp_sent = true;
		tp_order = context.trade.ResultOrder();
	}
	
	else if(!positioned)
	{
		tp_sent = false;
		if(context.order.Select(tp_order))
			context.trade.OrderDelete(tp_order);
	}
	
}