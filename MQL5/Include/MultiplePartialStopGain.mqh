//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar
/*
#include <Context.mqh>
#include <StopLoss.mqh>
Context context;
*/


class MultiplePartialStopGain
{	
	public:
	double distance1, distance2, distance3, distance4, distance5;
	double quantity1, quantity2, quantity3, quantity4, quantity5;
	bool tp_sent;
	ulong order1, order2, order3, order4, order5;
	bool using_break_even;
	StopLoss *stop_loss;
	
		
	void on_order(MqlTradeTransaction &trans);
	
	MultiplePartialStopGain(void);
	MultiplePartialStopGain(StopLoss *sl, double d1, double q1, double d2, double q2, double d3, double q3, double d4, double q4, double d5, double q5);
	~MultiplePartialStopGain(){};		
};

MultiplePartialStopGain::MultiplePartialStopGain(void){}

MultiplePartialStopGain::MultiplePartialStopGain(StopLoss *sl, double d1, double q1, double d2, double q2, double d3, double q3, double d4, double q4, double d5, double q5)
{
	stop_loss = sl;
	tp_sent = false;
	distance1 = sl.Distance;
}

void MultiplePartialStopGain::on_order(MqlTradeTransaction &trans)
{
/*
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
	*/
}