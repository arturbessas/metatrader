#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Generic\HashMap.mqh>
#include <SmarttbotApiV2.mqh>
#define MAX_SL_TP 10000.0

class Order
{	
	public:	
	double price;
	double stop_loss;
	double take_profit;
	string direction;
	Order(void);
	Order(double p, double sl, double tp, string direction);
	~Order(){};
};
Order::Order(void){}
Order::Order(double p,double sl,double tp,string d)
{
	price = p;
	stop_loss = sl;
	take_profit = tp;
	direction = d;
}

class SmarttOrder
{
	/* 
	Class responsible to do the communication between MT5 and Smarttbot API 
	*/
	
	// EA attributes
	string stock_code;
	CPositionInfo position_info;
	CTrade trade;
	double position_take_profit;
	double position_stop_loss;
	
	// Order atributes
	ulong identifier;	
	double price;
	double volume;
	double take_profit;
	double stop_loss;
	long timeout;
	string direction;
	string action;
	bool market_order;
	bool divergent_owned_stocks;
	datetime last_diverged_time;
	string last_position_type;
	
	
	ENUM_ORDER_STATE order_state;	
	CHashMap<ulong, Order*> pending_orders;	
	
	private:
	
	// Internal methods to set attributes values
	void init_from_order(void);
	void init_from_history(int index);	
	void reset_fields(void);
	void set_stock_code();
	void set_action(ENUM_ORDER_TYPE type);
	void set_timeout(long time_sent, long time_expiration);
	void set_direction(double vol=0);
	void set_stop_loss(double sl);
	void set_take_profit(double tp);
	void set_volume(double vol);
	
	// Internal methods to handle the requests
	void get_order_json(char &json[]);
	void get_cancel_json(char &json[], ulong ticket);
	void get_cancel_all_and_close_json(char &json[]);
	void get_modify_json(char &json[], ulong ticket, double new_price, double new_tp, double new_sl);
	string get_url(string signal_type);
	string get_headers();
	void send_order_signal(void);
	void send_request(string url, char &json[], char &result[]);
	
	// Utility methods
	bool is_bovespa(void) const {return SymbolInfoDouble(stock_code, SYMBOL_VOLUME_MIN) == 100.0;}
	void check_matching_owned_stocks(void);	
	
	public:
	
	SmarttOrder(void);
	~SmarttOrder(){};
	
	// Public methods to send requests
	void new_order(ulong ticket, int index=0);
	void send_cancel_orders(ulong ticket=0);
	void send_cancel_all_and_close(void);
	void send_modify_signal(ulong ticket, double new_price, double new_tp, double new_sl);
	
	void update_position_stops(void);
	void check_modified_position_stops(string stockCode);
	void check_modified_order(ulong ticket);
	void remove_order(ulong ticket);
	void update_owned_stocks(ENUM_ORDER_TYPE order_type, double vol);
	void check_divergent_number_of_stocks(void);
	
	double getOwnedStocks(string stockCode);
	void setOwnedStocks(string stockCode, double volume);
	
	CHashMap<string, double> ownedStocksMap;
	double current_owned_stocks;
	string authorization_token;
	bool is_staging;		
};

SmarttOrder::SmarttOrder(void)
{
	divergent_owned_stocks = false;
	for(int i=0; i<PositionsTotal(); i++)
	{
		string stockCode = PositionGetSymbol(i);
		if(position_info.SelectByMagic(stockCode, magic_number))
		{
			int signal = position_info.PositionType() == POSITION_TYPE_BUY ? 1 : -1;
			ownedStocksMap.Add(stockCode, signal * position_info.Volume());	
		}
	}
}

void SmarttOrder::new_order(ulong ticket, int index=0)
{
	/*
	Method called when there is a new pending order or when a new order
	appears at order history
	*/
	if(ticket == 0)
		return;
		
	reset_fields();
		
	identifier = ticket;

	if(OrderSelect(ticket))
		init_from_order();
	else
		init_from_history(index);
		
	if(direction == "exit" && volume == 100 && market_order)
		send_cancel_all_and_close();
	else
		send_order_signal();
}

//-------------
// Initialization methods
//-------------

void SmarttOrder::init_from_order(void)
{	
	/*
	If the new order comes from pending orders list
	use 'OrderGet' methods to get order data
	*/
	market_order = false;
	stock_code = OrderGetString(ORDER_SYMBOL);
	set_stock_code();
	price = OrderGetDouble(ORDER_PRICE_OPEN);	
	order_state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
	set_take_profit(OrderGetDouble(ORDER_TP));
	set_stop_loss(OrderGetDouble(ORDER_SL));
	set_action((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
	set_direction(OrderGetDouble(ORDER_VOLUME_INITIAL));
	set_volume(OrderGetDouble(ORDER_VOLUME_INITIAL));
	set_timeout(OrderGetInteger(ORDER_TIME_SETUP), OrderGetInteger(ORDER_TIME_EXPIRATION));
	
	pending_orders.Add(identifier, new Order(price, stop_loss, take_profit, direction));
}

void SmarttOrder::init_from_history(int index)
{
	/*
	If the new order comes from history orders list
	use 'HistoryOrderGet' methods to get order data.
	All orders at final state will come from there.
	*/
	HistorySelect(smartt_checker.initial_time, TimeCurrent() + 60*60);
	
	ulong ticket = HistoryOrderGetTicket(index);
	market_order = true;
	stock_code = HistoryOrderGetString(ticket, ORDER_SYMBOL);
	set_stock_code();
	price = HistoryOrderGetDouble(ticket, ORDER_PRICE_OPEN);
	order_state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket,ORDER_STATE);		
	set_take_profit(HistoryOrderGetDouble(ticket, ORDER_TP));
	set_stop_loss(HistoryOrderGetDouble(ticket, ORDER_SL));
	set_action((ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE));
	set_direction(HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL));
	set_volume(HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL));
	set_timeout(HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP), HistoryOrderGetInteger(ticket, ORDER_TIME_EXPIRATION));
}

double SmarttOrder::getOwnedStocks(string stockCode)
{
	double result;
	if(ownedStocksMap.TryGetValue(stockCode, result))
		return result;
	else
	{
		ownedStocksMap.Add(stockCode, 0);
		return 0;
	}
}

//-------------
// Set attributes methods
//-------------
void SmarttOrder::reset_fields(void)
{
	identifier = 0;
	price = 0.0;
	volume = 0.0;
	take_profit = 0.0;
	stop_loss = 0.0;
	timeout = 0;
	direction = "";
	action = "";
}


void SmarttOrder::set_stock_code()
{
	StringReplace(stock_code, "$", "%");
	set_new_stock_code(stock_code);
}


void SmarttOrder::set_action(ENUM_ORDER_TYPE type)
{
	if(StringFind(EnumToString(type), "BUY") >= 0)
		action = "buy";
	else if(StringFind(EnumToString(type), "SELL") >= 0)
		action = "sell";
	else if(StringFind(EnumToString(type), "CLOSE") >= 0) //order type close is an exit order
		action = last_position_type == "buy" ? "sell" : "buy";	
}

void SmarttOrder::set_timeout(long time_sent, long time_expiration)
{	
	timeout = MathAbs(time_expiration - time_sent);
}

void SmarttOrder::set_direction(double vol=0)
{
	/*
	Set order direction between [entry, exit, increase, reversal].
	If the order is already filled, we look at the order action and position type,
	if positioned,	to decide the direction. If not positioned, can only be an exit order.
	If it is a pending limit order, we also look at the order action and position type,
	and if not positioned, it can only be an entry order.
	*/
	double owned_stocks = MathAbs(current_owned_stocks);
	
	if(order_state == ORDER_STATE_FILLED)
	{	
		if(owned_stocks != 0)
		{
			string pos_type = current_owned_stocks > 0 ? "buy" : "sell";
			if(pos_type == action)
			{
				if(vol == owned_stocks)
					direction = "entry";
				else if(vol < owned_stocks)
					direction = "increase";
				else
					direction = "reversal";
			}
			else
				direction = "exit";
		}
		else
			direction = "exit";
	}
	else if(order_state == ORDER_STATE_PLACED)
	{
		if(owned_stocks != 0)
		{		
			string pos_type = current_owned_stocks > 0 ? "buy" : "sell";
			if(pos_type != action)
			{
				if(vol <= owned_stocks)
					direction = "exit";				
				else
					direction = "reversal";
			}
			else
				direction = "increase";
		}
		else
			direction = "entry";
	}		
}

void SmarttOrder::set_stop_loss(double sl)
{	
	// convert the stop loss price to distance from order price
	if(sl == 0.0)
		stop_loss = MAX_SL_TP;
	else
		stop_loss = MathAbs(price - sl);
}

void SmarttOrder::set_take_profit(double tp)
{
	// convert the stop gain price to distance from order price
	if(tp == 0.0)
		take_profit = MAX_SL_TP;
	else
		take_profit = MathAbs(price - tp);
}

void SmarttOrder::set_volume(double vol)
{	
	/* 
	set order volume in percentage using the direction and order state
	to check if is needed to use the current position volume or previous
	volume before order execution as reference
	*/
	double owned_stocks = MathAbs(current_owned_stocks);
	
	bool positioned = owned_stocks != 0;
	
	if(direction == "entry")
		volume = 0.0;
	else if(direction == "increase")
	{
		if(order_state == ORDER_STATE_FILLED)
		{
			double prev_stocks = owned_stocks - vol;
			volume = MathCeil(vol / prev_stocks * 100.0);
		}
		else if(order_state == ORDER_STATE_PLACED)
		{
			volume = MathCeil(vol / owned_stocks * 100.0);
		}
	}
	else if(direction == "exit")
	{
		if(positioned)
		{
			if(order_state == ORDER_STATE_FILLED)
			{
				double prev_stocks = owned_stocks + vol;
				volume = vol / prev_stocks * 100.0;
				volume = is_bovespa() ? MathCeil(volume) : MathFloor(volume);
			}
			else if(order_state == ORDER_STATE_PLACED)
			{
				volume = vol / owned_stocks * 100.0;
				volume = is_bovespa() ? MathCeil(volume) : MathFloor(volume);
			}
		}
		else
			volume = 100.0;
	}
	else if(direction == "reversal")
	{		
		if(order_state == ORDER_STATE_FILLED)
		{
			double prev_stocks = vol - owned_stocks;
			volume = MathCeil(owned_stocks / prev_stocks * 100.0);
		}
		else if(order_state == ORDER_STATE_PLACED)
		{
			volume = MathCeil((vol - owned_stocks) / owned_stocks * 100.0);
		}
	}
}

//-------------
// Request related methods
//-------------

string SmarttOrder::get_url(string signal_type)
{
	if(is_staging)
		return "https://api.k8s.smarttbot.com/signals/v1/order/" + signal_type;
	else
		return "https://api.smarttbot.com/signals/v1/order/" + signal_type;
}

string SmarttOrder::get_headers()
{
	return "Authorization: Bearer " + authorization_token;
}

void SmarttOrder::get_order_json(char &json[])
{
	/*
	Format the body of an order request according to Smarttbot API patterns
	*/
	string text = "";
	text += StringFormat("{\"strategy\":\"%s\",", strategy_id); 
	// {"strategy":"200",
	

	text += StringFormat("\"order\":{\"identifier\":\"%d\",\"action\":\"%s\",", identifier, action); 
	// {"strategy":"200","order":{"identifier":"11020122","action":"buy",	
	
	text += StringFormat("\"stock_code\":\"%s\"", stock_code);
	// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4"
	if(!market_order)
		text += StringFormat(",\"price\":\"%s\"", DoubleToString(price, 2));
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00"
	if(direction != "entry")
		text += StringFormat(",\"quantity\":\"%s\"", DoubleToString(volume, 2));
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00", "quantity":"50.00""
	if(!market_order)
		text += StringFormat(",\"timeout\":\"%s\",\"timeout_action\":\"cancel\"}", IntegerToString(timeout));
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00","timeout":"100","timeout_action":"cancel"}
	else
		text += "}";
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00"}
	if(direction == "entry" || direction == "reversal")
	{
		text += StringFormat(",\"stop_gain\":{\"distance\":\"%s\",\"method\":\"absolute\",\"order_type\":\"market\"},", DoubleToString(take_profit, 2));
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00","timeout":"100","timeout_action":"cancel"},
		// "stop_gain":{"distance":"50.00","method":"absolute","order_type":"market"},
		text += StringFormat("\"stop_loss\":{\"distance\":\"%s\",\"method\":\"absolute\"}}", DoubleToString(stop_loss, 2));
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00","timeout":"100","timeout_action":"cancel"},
		// "stop_gain":{"distance":"50.00","method":"absolute","order_type":"market"},
		// "stop_loss":{"distance":"50.00","method":"absolute"}}
	}
	else
		text += "}";
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00","timeout":"100","timeout_action":"cancel"}}
	
	StringToCharArray(text,json,0,StringLen(text));
}

void SmarttOrder::send_order_signal(void)
{
	string url = get_url(direction);	
	char result[];
	uchar json[];
	get_order_json(json);
	
	send_request(url, json, result);
}

void SmarttOrder::get_cancel_json(char &json[], ulong ticket)
{
	string text;
	if(ticket)
		text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"identifier\":\"%d\",\"stock_code\":\"%s\"}}", strategy_id, ticket, stock_code);
	else
		text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"stock_code\":\"%s\"}}", strategy_id, stock_code);
		
	StringToCharArray(text,json,0,StringLen(text));
}


void SmarttOrder::send_cancel_orders(ulong ticket=0)
{
	string url = get_url("cancel-all");
	char result[];
	uchar json[];	
	get_cancel_json(json, ticket);
	
	send_request(url, json, result);
}

void SmarttOrder::get_cancel_all_and_close_json(char &json[])
{
	string text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"stock_code\":\"%s\"}}", strategy_id, stock_code);
		
	StringToCharArray(text,json,0,StringLen(text));
}

void SmarttOrder::send_cancel_all_and_close(void)
{
	string url = get_url("close");
	char result[];
	uchar json[];	
	get_cancel_all_and_close_json(json);		
	
	send_request(url, json, result);
}

void SmarttOrder::send_request(string url, char &json[], char &result[])
{
	string headers = get_headers();
	string result_headers;
	Print("Requisição enviada, aguardando retorno.");
	int result_code = WebRequest("POST", url, headers, 5, json, result, result_headers);	
	if(result_code != 200)
		MessageBox("Erro ao enviar sinal. Procure o time de suporte. Erro: " + CharArrayToString(result));	
	Print(CharArrayToString(json));	
	Print(url);
	Print(headers);
}

void SmarttOrder::check_modified_order(ulong ticket)
{
	if(!OrderSelect(ticket) || !pending_orders.ContainsKey(ticket))
		return;

	double new_price = OrderGetDouble(ORDER_PRICE_OPEN);
	double new_tp = OrderGetDouble(ORDER_TP) == 0 ? MAX_SL_TP : MathAbs(new_price - OrderGetDouble(ORDER_TP));
	double new_sl = OrderGetDouble(ORDER_SL) == 0 ? MAX_SL_TP : MathAbs(new_price - OrderGetDouble(ORDER_SL));
	stock_code = OrderGetString(ORDER_SYMBOL);
	
	Order *order;
	if(!pending_orders.TryGetValue(ticket, order))
	{
		MessageBox("Erro ao modificar ordem.");
		return;
	}
	
	if(new_price == order.price)
		new_price = 0.0;
	else
		order.price = new_price;
	
	if(new_tp == order.take_profit)
		new_tp = 0.0;
	else
		order.take_profit = new_tp;
		
	if(new_sl == order.stop_loss)
		new_sl = 0.0;
	else
		order.stop_loss = new_sl;
		
	if(new_price || new_tp || new_sl)
		send_modify_signal(ticket, new_price, new_tp, new_sl);
}

void SmarttOrder::send_modify_signal(ulong ticket, double new_price, double new_tp, double new_sl)
{
	string url = get_url("modify");
	char result[];
	uchar json[];	
	get_modify_json(json, ticket, new_price, new_tp, new_sl);
	
	set_stock_code();
	
	send_request(url, json, result);
}

void SmarttOrder::get_modify_json(char &json[], ulong ticket, double new_price, double new_tp, double new_sl)
{
	string text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"stock_code\":\"%s\"", strategy_id, stock_code);
	if(ticket)
		text += StringFormat(",\"identifier\":\"%d\"", ticket);
	if(new_price)
		text += StringFormat(",\"price\":\"%.2f\"", new_price);
	if(new_tp)
		text += StringFormat(",\"stop_gain\":\"%.2f\"", new_tp);
	if(new_sl)
		text += StringFormat(",\"stop_loss\":\"%.2f\"", new_sl);
	text += "}}";
	
	StringToCharArray(text,json,0,StringLen(text));
}

void SmarttOrder::remove_order(ulong ticket)
{
	Order *order;
	if(pending_orders.TryGetValue(ticket, order))
	{
		delete(order);
		pending_orders.Remove(ticket);
	}
}

void SmarttOrder::update_position_stops(void)
{
	if(position_info.SelectByMagic(stock_code, magic_number))
	{
		position_take_profit = position_info.TakeProfit();
		position_stop_loss = position_info.StopLoss();
	}
}

void SmarttOrder::check_modified_position_stops(string stockCode)
{
	stock_code = stockCode;
	// check if the current position stops has changed and send the modify signal if needed
	if(!position_info.SelectByMagic(stock_code, magic_number))
		return;
		
	double new_tp = 0.0, new_sl = 0.0;
	
	if(position_info.TakeProfit() != position_take_profit)
		new_tp = position_info.TakeProfit() == 0.0 ? MAX_SL_TP : MathAbs(position_info.TakeProfit() - position_info.PriceOpen());
	
	if(position_info.StopLoss() != position_stop_loss)
		new_sl = position_info.StopLoss() == 0.0 ? MAX_SL_TP : MathAbs(position_info.StopLoss() - position_info.PriceOpen());
		
	if(new_tp || new_sl)
	{
		send_modify_signal(0, 0.0, new_tp, new_sl);
		update_position_stops();
	}
}

void SmarttOrder::(ENUM_ORDER_TYPE order_type, double vol)
{
	set_action(order_type);
	if(action == "buy")
		current_owned_stocks += vol;
	else if(action == "sell")
		current_owned_stocks -= vol;
		
	if(current_owned_stocks > 0)
		last_position_type = "buy";
	else if(current_owned_stocks < 0)
		last_position_type = "sell";
		
	//check_matching_owned_stocks();	
		
	PrintFormat("Owned stocks: %.2f", current_owned_stocks);
}

void SmarttOrder::check_matching_owned_stocks()
{
	/*
	Checks if owned stocks monitored by SmarttOrder matches owned stocks at MT5.
	If not, wait 10 seconds and check again. If doesn't match, sends an alert.
	*/
	if(divergent_owned_stocks)
		return;
		
	if(position_info.SelectByMagic(stock_code, magic_number))
	{
		if(position_info.Volume() != MathAbs(current_owned_stocks))
			divergent_owned_stocks = true;
	}
	else if(current_owned_stocks != 0)
		divergent_owned_stocks = true;
		
	if(divergent_owned_stocks)
	{
		last_diverged_time = TimeCurrent();
	}
}

void SmarttOrder::check_divergent_number_of_stocks()
{
	if(divergent_owned_stocks && TimeCurrent() - last_diverged_time >= 10)
	{
		divergent_owned_stocks = false;
		check_matching_owned_stocks();
		if(divergent_owned_stocks)
		{
			MessageBox("É possível que os sinais estejam dessincronizados com o MT5. Verifique seu robô na Smarttbot.");
			last_diverged_time = TimeCurrent();
		}
	}
}