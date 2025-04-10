//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar
/*
#include <Enums.mqh>
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
#include <Trade\OrderInfo.mqh>
CTrade trade;
CPositionInfo pos_info;
Context *context;
COrderInfo order;
input int elim_hour = 17; //Hora final de eliminação
input int elim_min = 30;
*/ 
// fim apagar




class PositionIncreaser: public Node
{	
	public:
	
	int step;
	ulong last_increase_order;
	double distances[];
	double quantities[];
	
	PositionIncreaser(void){}
	~PositionIncreaser(){};
	
	PositionIncreaser(double d1, double q1, double d2=0, double q2=0, double d3=0, double q3=0)
	{
		step = 0;
		last_increase_order = NULL;
		
		//build lists
		if(d1 > 0 && q1 > 0)
		{
			add(distances, d1);
			add(quantities, q1);
			
			if(d2 > d1 && q2 > 0)
			{
				add(distances, d2);
				add(quantities, q2);
				
				if(d3 > d2 && q3 > 0)
				{
					add(distances, d3);
					add(quantities, q3);
				}
			}
		}
	}
	
		
	void on_order(MqlTradeTransaction &trans)
	{
		if(trans.order_state != ORDER_STATE_FILLED)
		return;
		
		bool positioned = context.pos_info.Select(Symbol());
		if(!positioned)
		{
			reset_module();
			return;
		}
		
		if(step == 0 || trans.order == last_increase_order)
		{
			send_next_increase();
		}
	}
	
	void reset_module(void)
	{
		if(context.order.Select(last_increase_order))
			context.trade.OrderDelete(last_increase_order);
		step = 0;
		last_increase_order = NULL;
		return;
	}
	
	void send_next_increase(void)
	{
		if(step >= ArraySize(distances))
			return;
		
		 double multiplier = context.pos_info.PositionType() == POSITION_TYPE_SELL ? 1 : -1;
		 double diff = distances[step] * multiplier;
		 double price = context.position.entry_price + diff;
		 
		 if(context.pos_info.PositionType() == POSITION_TYPE_BUY)
			context.trade.BuyLimit(quantities[step], context.round_price(price), Symbol(), 0, 0, ORDER_TIME_GTC, 0, "Increase " + IntegerToString(step+1));
		else
			context.trade.SellLimit(quantities[step], context.round_price(price), Symbol(), 0, 0, ORDER_TIME_GTC, 0, "Increase " + IntegerToString(step+1));
		
		last_increase_order = context.trade.ResultOrder();
		step++;
	}
	
	
	void add(int &v[], int x)
	{
		int size = ArraySize(v);
		ArrayResize(v, size+1);
		v[size] = x;
	}

	void add(double &v[], double x)
	{
		int size = ArraySize(v);
		ArrayResize(v, size+1);
		v[size] = x;
	}
};

/*
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

*/