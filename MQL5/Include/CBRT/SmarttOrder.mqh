#include <Trade\PositionInfo.mqh>
#include <Generic\HashMap.mqh>
#include <Metabot\BaseClasses.mqh>
#define MAX_SL_TP 10000.0
#define VERSION "CBRT2022"
#define MAX_TRIES 5


class SmarttOrder
{
	/* 
	Class responsible to do the communication between MT5 and Smarttbot API 
	*/
	
	// EA attributes
	string stock_code;
	string mt5_stock_code;
	CPositionInfo position_info;
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
	
	private:
	
	// Internal methods to set attributes values
	void init_from_order(void);
	void init_from_history(int index);	
	void reset_fields(void);
	void set_stock_code(string stockCode);
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
	bool full_lot(void) const {return SymbolInfoDouble(mt5_stock_code, SYMBOL_VOLUME_MIN) == 100.0;}
	bool is_fractionary(void) const {return mt5_stock_code[StringLen(mt5_stock_code) - 1] == 'F';}
	void check_matching_owned_stocks(void);	
	
	public:
	
	SmarttOrder(string stockCode, Position *initial_position);
	~SmarttOrder(){};
	
	// Public methods to send requests
	void new_order(ulong ticket, int index=0);
	void send_cancel_orders(ulong ticket=0);
	void send_cancel_all_and_close(void);
	void send_modify_signal(ulong ticket, double new_price, double new_tp, double new_sl);
	
	void update_position_stops(void);
	void check_modified_position_stops(void);
	void check_modified_order(ulong ticket);
	void remove_order(ulong ticket);
	void update_owned_stocks(ENUM_ORDER_TYPE order_type, double vol, double price);
	void update_average_price(double owned_stocks_delta, double price);
	void check_divergent_number_of_stocks(void);
	bool get_authorization(bool force = false);
	
	double current_owned_stocks;
	double average_price;
	double first_entry_price;
	bool is_staging;
	CHashMap<ulong, Order*> pending_orders;

};

SmarttOrder::SmarttOrder(string stockCode, Position *initial_position)
{
	divergent_owned_stocks = false;
	set_stock_code(stockCode);	
	if(initial_position != NULL)
	{
		current_owned_stocks = initial_position.volume;
		average_price = initial_position.price_open;
		first_entry_price = average_price;
	}
	else
	{
		current_owned_stocks = 0;
		average_price = 0;
		first_entry_price = 0;
	}
	PrintFormat("Initial position of %s: %f", stockCode, current_owned_stocks);
	
	is_staging = GlobalVariableGet("SMARTTBOT_IS_STAGING") > 0;
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
	price = OrderGetDouble(ORDER_PRICE_OPEN);
	order_state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
	set_take_profit(OrderGetDouble(ORDER_TP));
	set_stop_loss(OrderGetDouble(ORDER_SL));
	set_action((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
	set_direction(OrderGetDouble(ORDER_VOLUME_INITIAL));
	set_volume(OrderGetDouble(ORDER_VOLUME_INITIAL));
	set_timeout(OrderGetInteger(ORDER_TIME_SETUP), OrderGetInteger(ORDER_TIME_EXPIRATION));
	
	pending_orders.Add(identifier, new Order(price, stop_loss, take_profit, direction, volume));
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
	price = HistoryOrderGetDouble(ticket, ORDER_PRICE_CURRENT);
	order_state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket,ORDER_STATE);		
	set_take_profit(HistoryOrderGetDouble(ticket, ORDER_TP));
	set_stop_loss(HistoryOrderGetDouble(ticket, ORDER_SL));
	set_action((ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE));
	set_direction(HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL));
	set_volume(HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL));
	set_timeout(HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP), HistoryOrderGetInteger(ticket, ORDER_TIME_EXPIRATION));
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


void SmarttOrder::set_stock_code(string stockCode)
{
	mt5_stock_code = stockCode;
	stock_code = stockCode;
	StringReplace(stock_code, "$", "%");
	if(StringSubstr(stock_code, 0, 3) == "WIN")
		stock_code = "WIN%";
	else if(StringSubstr(stock_code, 0, 3) == "WDO")
		stock_code = "WDO%";
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
	//if(sl == 0.0)
	stop_loss = MAX_SL_TP;
	//else
		//stop_loss = MathAbs(price - sl);
}

void SmarttOrder::set_take_profit(double tp)
{
	// convert the stop gain price to distance from order price
	//if(tp == 0.0)
	take_profit = MAX_SL_TP;
	//else
		//take_profit = MathAbs(price - tp);
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
	{
		if(is_fractionary() || full_lot())
			volume = vol;
		else
			volume = 0.0;
	}
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
				volume = full_lot() ? MathCeil(volume) : MathFloor(volume);
			}
			else if(order_state == ORDER_STATE_PLACED)
			{
				volume = vol / owned_stocks * 100.0;
				volume = full_lot() ? MathCeil(volume) : MathFloor(volume);
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
	text += StringFormat("{\"strategy\":\"%s\",", IntegerToString(strategy_id)); 
	// {"strategy":"200",
	

	text += StringFormat("\"order\":{\"identifier\":\"%d\",\"action\":\"%s\",", identifier, action); 
	// {"strategy":"200","order":{"identifier":"11020122","action":"buy",	
	
	text += StringFormat("\"stock_code\":\"%s\"", stock_code);
	// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4"
	if(!market_order)
		text += StringFormat(",\"price\":\"%s\"", DoubleToString(price, 2));
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00"
	if(volume)
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
		text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"identifier\":\"%d\",\"stock_code\":\"%s\"}}", IntegerToString(strategy_id), ticket, stock_code);
	else
		text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"stock_code\":\"%s\"}}", IntegerToString(strategy_id), stock_code);
		
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
	string text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"stock_code\":\"%s\"}}", IntegerToString(strategy_id), stock_code);
		
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
	// this stock code is used only for authentication purposes. It should not send signals
	if(stock_code == "default")
		return;
		
	string headers = get_headers();
	string result_headers;
	Print("Requisição enviada, aguardando retorno.");
	int result_code = 0, tries = 0;
	while(result_code != 200 && tries++ < MAX_TRIES)
	{
		result_code = WebRequest("POST", url, headers, 5, json, result, result_headers);
		if(result_code != 200)
		{
			Print(StringFormat("Falha no envio do sinal. Tentativa %d/%d.", tries, MAX_TRIES));
			if(tries > 1)
				Sleep(1000);
			get_authorization(true);
			headers = get_headers();
		}
	}
	if(result_code != 200)
		MessageBox("Erro ao enviar sinal. Procure o time de suporte. Erro: " + CharArrayToString(result));	
	Print(CharArrayToString(json));	
	Print(url);
	//Print(headers);
}

void SmarttOrder::check_modified_order(ulong ticket)
{
	if(!OrderSelect(ticket) || !pending_orders.ContainsKey(ticket))
		return;

	double new_price = OrderGetDouble(ORDER_PRICE_OPEN);
	double new_tp = OrderGetDouble(ORDER_TP) == 0 ? MAX_SL_TP : MathAbs(new_price - OrderGetDouble(ORDER_TP));
	double new_sl = OrderGetDouble(ORDER_SL) == 0 ? MAX_SL_TP : MathAbs(new_price - OrderGetDouble(ORDER_SL));
	
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
	
	send_request(url, json, result);
}

void SmarttOrder::get_modify_json(char &json[], ulong ticket, double new_price, double new_tp, double new_sl)
{
	string text = StringFormat("{\"strategy\":\"%s\",\"order\":{\"stock_code\":\"%s\"", IntegerToString(strategy_id), stock_code);
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
	double signal = current_owned_stocks > 0 ? 1 : -1;
	
	if(position_info.SelectByMagic(mt5_stock_code, magic_number))
	{
		position_take_profit = position_info.TakeProfit() == 0.0 ? MAX_SL_TP : signal * (position_info.TakeProfit() - average_price);
		position_stop_loss = position_info.StopLoss() == 0.0 ? MAX_SL_TP : signal * (average_price - position_info.StopLoss());
	}
}

void SmarttOrder::check_modified_position_stops(void)
{
	// check if the current position stops has changed and send the modify signal if needed
	if(!position_info.SelectByMagic(mt5_stock_code, magic_number))
		return;
	
	double previous_tp = position_take_profit;
	double previous_sl = position_stop_loss;
	
	update_position_stops();
	
	bool changed_tp = previous_tp != position_take_profit;
	bool changed_sl = previous_sl != position_stop_loss;
		
	if(changed_sl || changed_tp)
	{
		send_modify_signal(0, 0.0, position_take_profit, position_stop_loss);
	}
}

void SmarttOrder::update_average_price(double owned_stocks_delta, double order_price)
{
	// full exit
	if(current_owned_stocks + owned_stocks_delta == 0)
	{
		average_price = 0;
		first_entry_price = 0;
	}
	// entry or increase	
	else if(MathAbs(current_owned_stocks + owned_stocks_delta) > MathAbs(current_owned_stocks))
	{
		average_price = MathAbs((current_owned_stocks * average_price + owned_stocks_delta * order_price) / (current_owned_stocks + owned_stocks_delta));
		if(first_entry_price == 0)
			first_entry_price = order_price;
	}
	// reversal
	else if(MathAbs(owned_stocks_delta) > MathAbs(current_owned_stocks))
	{
		average_price = order_price;
		first_entry_price = order_price;
	}
}

void SmarttOrder::update_owned_stocks(ENUM_ORDER_TYPE order_type, double vol, double order_price)
{	
	set_action(order_type);
	double owned_stocks_delta = action == "buy" ? vol : -vol;
	
	update_average_price(owned_stocks_delta, order_price);
	
	current_owned_stocks += owned_stocks_delta;
		
	if(current_owned_stocks > 0)
		last_position_type = "buy";
	else if(current_owned_stocks < 0)
		last_position_type = "sell";
		
	check_matching_owned_stocks();	
		
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
		
	if(position_info.SelectByMagic(mt5_stock_code, magic_number))
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

bool SmarttOrder::get_authorization(bool force = false)
{
	string url = "https://api.smarttbot.com/signals/v1/auth/login";
	if(is_staging)
		url = "https://api.k8s.smarttbot.com/signals/v1/auth/login";
		
	
	uchar json[];
	char result[];
	string result_headers;
	
	string data = StringFormat("{\"username\":\"%s\",\"password\":\"%s\"}", login, password);
	StringToCharArray(data, json, 0, StringLen(data));
	int res = WebRequest("POST", url, NULL, NULL, json, result, result_headers);
	if(res != 200 && !first_login)
	{
		MqlDateTime now;
		TimeCurrent(now);
		if(now.hour == 8 && now.min >= 50)
			SendNotification("A autenticação de seu robô da API Smarttbot falhou. Reinicie seu script/EA no Metatrader.");
		if(!force)
		{
			Print("Erro no login. Tentando novamente em 60 segundos.");
			Sleep(60000);
		}
	}
	else if(res == -1)
	{
		MessageBox("Erro de comunicação com o servidor. Verifique se as URLs https://api.smarttbot.com/ e https://api.k8s.smarttbot.com/ estão liberadas em Ferramentas -> Opções -> Expert Advisors");
	}
	else if(res == 503 || res == 504)
	{
		MessageBox("Timeout do servidor. Tente iniciar o script novamente ou procure o time da Smarttbot.");
	}
	else if(res == 401)
	{
		MessageBox("Erro ao autenticar usuário. Verifique login e senha.");
	}
	else if(res == 200)
	{
		string aux_str[], aux2[];
		StringSplit(CharArrayToString(result), StringGetCharacter(",",0), aux_str);
		StringSplit(aux_str[0], StringGetCharacter(":",0), aux2);
		authorization_token = StringSubstr(aux2[1], 1, StringLen(aux2[1]) - 2);
		if(first_login)
		{
			MessageBox("Olá, " + login + ". Metabot iniciado com sucesso. Versão: " + VERSION);
			first_login = false;
		}
		else
		{
			Print("Nova autenticação efetuada com sucesso.");
		}
		PrintFormat("Strategy ID: %s. Magic number: %d. Account type: %d. Versão: %s", IntegerToString(strategy_id), magic_number, AccountInfoInteger(ACCOUNT_MARGIN_MODE), VERSION);
		
		return true;
	}
	
	return false;
}