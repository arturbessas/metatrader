//+------------------------------------------------------------------+
//|                                                      Context.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

#include <Arrays\ArrayObj.mqh>
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Optimizer.mqh>
#include <Object.mqh>
#include <Basic.mqh>


#define TIMEOUT 60
#define MAX_TRIES 5 

struct TickInfo
{
	MqlTick tick;
	MqlDateTime time;
};


class Node: public CObject
{
	public:
	virtual void on_trade(void){};
	virtual void on_order(MqlTradeTransaction &trans){};
	virtual void on_exit(void){};
	Node(void){};
	~Node(){};
};

class Rule: public Node
{
	public:
	string Signal;	
	Rule(void){};
	~Rule(){};
};

struct Position
{
	double volume;
	double entry_price;
	double average_price;
	ulong positions[];
};

class Context
{	
	public:
	//basic
	CTrade trade;
	COrderInfo order_info;
	CHistoryOrderInfo history_order_info;
	CPositionInfo pos_info;
	Optimizer *optimizer;
	
	void on_order(MqlTradeTransaction &trans);
	void on_trade(void);
	void on_exit(void);
	bool Buy(double volume, string comment);
	bool Sell(double volume, string comment);
	bool ClosePositionByTicket(ulong ticket, string comment);
	bool ClosePositions(string comment);
	
	string stock_code;
	ulong magic_number;
	datetime start_time;
	datetime last_candle_time;
	bool valid_strategy;
	bool is_new_bar;
	bool entries_locked;
	bool daily_locked;
	TickInfo tick;
	ulong pending_orders[];
	Position position;
	MqlDateTime now;

	ENUM_TIMEFRAMES periodicity;
	
	CArrayObj *on_trade_nodes;
	CArrayObj *on_order_nodes;
	
	
	double current_price(void) {return tick.tick.bid;}
	bool is_new_day(void) {return optimizer.is_new_day;}
	bool is_positioned(void) {return position.volume != 0;}
	bool is_bought(void) {return position.volume > 0;}
	bool is_sold(void) {return position.volume < 0;}
	int positions_quantity(void) {return ArraySize(position.positions);}
	double entry_price(void) {return position.entry_price;}
	double number_of_stocks_to_trade(void) {return number_of_stocks;}
	double average_price(void) {return position.average_price;}
	datetime today(void) {return int(TimeCurrent() / (60 * 60 * 24)) * (60 * 60 * 24);}
	
	bool check_times(int h_ini, int m_ini, int h_end, int m_end);
	int compare_time(MqlDateTime &mql_time, int hour, int min);
	void check_new_bar(void);
	double round_price(double price);
	void check_entry_timeout();
	bool is_testing(void);
	double get_daily_profit(void);
	double get_position_price(ulong position_ticket);

	
	Context(string stockCode, ulong magicNumber, ENUM_TIMEFRAMES Periodicity);
	~Context(){};
	
	private:
	void update_orders(void);
	void reset_position(void);
	void update_position(ulong order_ticket);
	void add_position(ulong position_ticket);	
	void load_positions(void);
};

Context::Context(string stockCode, ulong magicNumber, ENUM_TIMEFRAMES Periodicity)
{
	stock_code = stockCode;
	periodicity = Periodicity;
	magic_number = magicNumber;
	trade.SetExpertMagicNumber(magic_number);
	trade.SetTypeFilling(ORDER_FILLING_RETURN);
	optimizer = new Optimizer();
	start_time = TimeCurrent();
	valid_strategy = true;
	last_candle_time = 0;
	entries_locked = false;
	daily_locked = false;
	
	// last price
	ResetLastError();
	if (!SymbolInfoTick(stock_code, tick.tick))
	{
	   logger.error("Initial Tick error: " + IntegerToString(GetLastError()));
	   return;
	}
	logger.info("Initial price: " + DoubleToString(current_price()));
	
	on_trade_nodes = new CArrayObj;
	on_order_nodes = new CArrayObj;
	
	load_positions();
	
	logger.info("Successfull initialization. Number of positions loaded: " + IntegerToString(positions_quantity()));
}

void Context::load_positions(void)
{  
   int total = PositionsTotal();
   for (int i = 0; i < total; i++)
   {
      if (!pos_info.SelectByIndex(i))
         continue;
      
      if (pos_info.Symbol() != stock_code || pos_info.Magic() != magic_number)
         continue;
      
      logger.info("Initial position identified. Loading positions...");
      
      update_position(pos_info.Ticket());      
   }
}

void Context::on_exit(void)
{
   delete optimizer;
	// delete on trade nodes
	for(int i = 0; i < on_trade_nodes.Total(); i++)
	{
		Node *node = on_trade_nodes.At(i);
		node.on_exit();
		delete node;
	}
	delete on_trade_nodes;
	
	// delete on order nodes
	for(int i = 0; i < on_order_nodes.Total(); i++)
	{
		Node *node = on_order_nodes.At(i);
		node.on_exit();
		delete node;
	}
	delete on_order_nodes;	
}

void Context::on_order(MqlTradeTransaction &trans)
{
   ulong order_ticket = trans.order;
   
   if(!HistoryOrderSelect(order_ticket) || HistoryOrderGetInteger(order_ticket, ORDER_MAGIC) != magic_number)
      return;
	
	for(int i = 0; i < on_order_nodes.Total(); i++)
	{
		Node *node = on_order_nodes.At(i);
		node.on_order(trans);
	}
}


void Context::on_trade()
{
   if(!valid_strategy)
		ExpertRemove();
		
   // check for order updates
   if (ArraySize(pending_orders) > 0)
      update_orders();

   ResetLastError();
	if (!SymbolInfoTick(stock_code, tick.tick))
	{
	   logger.error("Tick error: " + IntegerToString(GetLastError()));
	   return;
	}
	TimeToStruct(tick.tick.time, now);
	
	//optmization checks
	optimizer.on_trade();
	
	if(optimizer.is_new_day)
		daily_locked = false;	

   int size = on_trade_nodes.Total();
	for(int i = 0; i < size; i++)
	{
		Node *node = on_trade_nodes.At(i);
		node.on_trade();
	}
}

void Context::update_orders(void)
{
   ulong stop_watching_orders[];
   
   // update pending orders status
   int size = ArraySize(pending_orders);
   for(int i = 0; i < size; i++)
   {
      if (HistoryOrderSelect(pending_orders[i]))
      {      
         ulong order_ticket = pending_orders[i];
         // check order state
         if (HistoryOrderGetInteger(order_ticket, ORDER_STATE) != ORDER_STATE_FILLED)
         {
            logger.error("Error! Order in history but not executed. Id: " + IntegerToString(order_ticket));
         }
         else
         {
            // update position info
            ulong position_ticket = HistoryOrderGetInteger(order_ticket,ORDER_POSITION_ID);
            if (pos_info.SelectByTicket(position_ticket) && !contains(position.positions, position_ticket))
               add_position(position_ticket);
            else
               update_position(order_ticket);
         }               
         
         // set pending order to be removed
         append(stop_watching_orders, order_ticket);
      }
   }   
   
   // remove final state orders
   size = ArraySize(stop_watching_orders);
   for(int i = 0; i < size; i++)
   {
      remove_item(pending_orders, stop_watching_orders[i]);
   }
   
}

void Context::update_position(ulong order_ticket)
{
   history_order_info.Ticket(order_ticket);
   
   if (is_buy_order_type(history_order_info.OrderType()))
      position.volume += history_order_info.VolumeInitial();
   else if (is_sell_order_type(history_order_info.OrderType()))
      position.volume -= history_order_info.VolumeInitial();
      
   ulong position_ticket = history_order_info.PositionId();
   if (!pos_info.SelectByTicket(position_ticket))
      remove_item(position.positions, position_ticket);
   
   if (ArraySize(position.positions) == 0)
      reset_position();
      
   string msg = StringFormat("Position updated according order ticket %d. \nEntry price: %f \nAverage Price: %f \nVolume: %f",
                              order_ticket, position.entry_price, position.average_price, position.volume);
      
   logger.info(msg);
}

void Context::reset_position(void)
{
   if (NormalizeDouble(position.volume, 10) != 0)
      logger.error("Error! Reseting position wihout being zeroed. Current position: " + DoubleToString(position.volume));
      
   position.volume = 0;
   position.entry_price = 0;
   position.average_price = 0;
}

void Context::add_position(ulong position_ticket)
{
   if (!pos_info.SelectByTicket(position_ticket))
   {
      logger.error("Error selecting position. Something went wrong. Id: " + IntegerToString(position_ticket));
      return;
   }
   
   append(position.positions, position_ticket);
   
   // update entry price if not positioned
   if (position.entry_price == 0)      
      position.entry_price = pos_info.PriceOpen();
   // update average price
   position.average_price = (MathAbs(position.volume)*position.average_price + pos_info.Volume()*pos_info.PriceOpen()) / (MathAbs(position.volume) + pos_info.Volume());
   // update volume
   if (pos_info.PositionType() == POSITION_TYPE_BUY)
      position.volume += pos_info.Volume();
   else if (pos_info.PositionType() == POSITION_TYPE_SELL)
      position.volume -= pos_info.Volume();
      
   string msg = StringFormat("Position updated according position ticket %d. \nEntry price: %f \nAverage Price: %f \nVolume: %f",
                              position_ticket, position.entry_price, position.average_price, position.volume);
      
   logger.info(msg);
}

bool Context::ClosePositions(string comment)
{
   bool success = true;
   for(int i = 0; i < ArraySize(position.positions); i++)
   {
      success = success && ClosePositionByTicket(position.positions[i], comment);
   }   
   
   return success;
}

bool Context::ClosePositionByTicket(ulong ticket, string comment)
{
   int tries = 0;
	uint result = 0;
   while(tries < MAX_TRIES && result != 10009 && result != 10018 && trade.PositionClose(ticket, comment)) // 10018 = Market Closed
	{
		result = trade.ResultRetcode();
		tries++;
		if(result != 10009)
		{
			Sleep(100);
		}
	}
	if (result == 10009)
	{
	   append(pending_orders, trade.ResultOrder());
	   return true;
	}
	else
	{
	   logger.info("Error closing position. Ticket: " + IntegerToString(ticket) + " " + IntegerToString(result) + " Reason: " + comment);
	   return false;
	}
}


bool Context::check_times(int h_ini, int m_ini, int h_end, int m_end)
{
	check_entry_timeout();
		
		
	check_new_bar();
		
	return true;	
}

int Context::compare_time(MqlDateTime &mql_time, int hour, int min)
{
	if(mql_time.hour == hour && mql_time.min == min)
		return 0;
	if(mql_time.hour > hour || (hour == mql_time.hour && mql_time.min > min))
		return 1;
	else
		return -1;
}

void Context::check_new_bar()
{
	datetime current_candle_time = iTime(stock_code, periodicity, 0);
	if(last_candle_time != current_candle_time)
	{
		last_candle_time = current_candle_time;
		is_new_bar = true;
	}
	else
	{
		is_new_bar = false;
	}
}

double Context::round_price(double price)
{
	double min_var = 0.01;
	if(StringFind(stock_code, "WIN") >= 0)
		min_var = 5.0;
	else if(StringFind(stock_code, "WDO") >= 0)
		min_var = 0.5;
	else
		min_var = 0.1;
	double ticks = price / min_var;
	return round(ticks) * min_var;
}

void Context::check_entry_timeout(void)
{
	if(pos_info.Select(stock_code))
		return;
	
	for(int i = 0; i < OrdersTotal(); i++)
	{
		order_info.SelectByIndex(i);
		if(TimeCurrent() - order_info.TimeSetup() > TIMEOUT)
		{
			trade.OrderDelete(order_info.Ticket());
			entries_locked = false;
		}
	}	 
}



bool Context::is_testing(void)
{
	if(!MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION) && !MQLInfoInteger(MQL_FORWARD))
	{
		//MessageBox("EA exclusivo para testes. Para operar Price Action, acesse smarttbot.com");
		return false;
	}
	return true;
}

double Context::get_daily_profit(void)
{	
	HistorySelect(TimeCurrent() - 12*60*60, TimeCurrent()); // now - 12h until now
	ulong ticket;
	double result = 0;
	
	for(int i = 0; i < HistoryDealsTotal(); i++)
	{
		ticket = HistoryDealGetTicket(i);
		result += HistoryDealGetDouble(ticket, DEAL_PROFIT);
	}
	
	if(pos_info.Select(stock_code))
	{
		result += pos_info.Profit();
	}
	
	return result;
}

bool Context::Buy(double volume, string comment="")
{
   if (ArraySize(pending_orders) > 0)
   {
      logger.info("Blocking order due to pending orders. New order reason: " + comment);
      return false;
   }
	int tries = 0;
	uint result = 0;
	while(tries < MAX_TRIES && result != 10009)
	{
		trade.Buy(volume, stock_code, tick.tick.ask, 0, 0, comment);
		result = trade.ResultRetcode();
		tries++;
		if(result != 10009)
		{
			Sleep(100);
		}
	}
	if (result == 10009)
	{
	   append(pending_orders, trade.ResultOrder());
	   return true;
	}
	else
	{
	   logger.info("Order couldn't be placed. Code: " + trade.ResultRetcodeDescription());
	   return false;
	}
}

bool Context::Sell(double volume, string comment="")
{
   if (ArraySize(pending_orders) > 0)
   {
      logger.info("Blocking order due to pending order. New order reason: " + comment);
      return false;
   }
	int tries = 0;
	uint result = 0;
	while(tries < MAX_TRIES && result != 10009)
	{
		trade.Sell(volume, stock_code, tick.tick.bid, 0, 0, comment);
		result = trade.ResultRetcode();
		tries++;
		if(result != 10009)
		{
			Sleep(100);
		}
	}
	if (result == 10009)
	{
	   append(pending_orders, trade.ResultOrder());
	   return true;
	}
	else
	{
	   logger.info("Order couldn't be placed. Code: " + trade.ResultRetcodeDescription());
	   return false;
	}
}

double Context::get_position_price(ulong position_ticket)
{
	if(!pos_info.SelectByTicket(position_ticket))
		logger.error(StringFormat("%s: ticket: %lld.", __FUNCTION__, position_ticket));
		
	return pos_info.PriceOpen();
}