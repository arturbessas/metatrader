#include <Trade\PositionInfo.mqh>
#include <Generic\HashMap.mqh>
#include "BaseClasses.mqh"
#define VERSION "4.0.0"
#define MAX_TRIES 5

class SmarttOrder
{
	/* 
	Class responsible to do the communication between MT5 and Smarttbot API 
	*/
	
	// EA attributes
	string stock_code;
	string mt5_stock_code;
	
	// Order atributes
	ulong identifier;	
	double volume;
	string direction;
	string action;	
	
	private:
	
	// Internal methods to set attributes values
	void reset_fields(void);
	void set_stock_code(string stockCode);
	void set_action(ENUM_DEAL_TYPE type);
	void set_direction(double vol=0);
	void set_volume(double vol);
	
	// Internal methods to handle the requests
	void get_order_json(char &json[]);
	void get_cancel_all_and_close_json(char &json[]);
	string get_url(string signal_type);
	string get_headers();
	void send_order_signal(void);
	void send_request(string url, char &json[], char &result[]);
	
	// Utility methods
	bool full_lot(void) const {return SymbolInfoDouble(mt5_stock_code, SYMBOL_VOLUME_MIN) == 100.0;}
	bool is_fractionary(void) const {return mt5_stock_code[StringLen(mt5_stock_code) - 1] == 'F';}
	
	public:
	
	SmarttOrder(string stockCode, double initial_position);
	~SmarttOrder(){};
	
	// Public methods to send requests
	void new_deal(ulong ticket, ENUM_DEAL_TYPE dealType, double vol);
	void send_cancel_all_and_close(void);
	
	void update_owned_stocks(ENUM_DEAL_TYPE deal_type, double vol, double price);
	void update_average_price(double owned_stocks_delta, double price);
	bool get_authorization(bool force = false);
	
	double current_owned_stocks;
	double average_price;
	double first_entry_price;
	bool is_staging;
};

SmarttOrder::SmarttOrder(string stockCode, double initial_position)
{
	set_stock_code(stockCode);	
	current_owned_stocks = initial_position;
	
	PrintFormat("Initial position of %s: %f", stockCode, current_owned_stocks);
	
	is_staging = GlobalVariableGet("SMARTTBOT_IS_STAGING") > 0;
}


void SmarttOrder::new_deal(ulong ticket, ENUM_DEAL_TYPE dealType, double vol)
{
	/*
	Method called when a new deal appears at order history
	*/
	if(ticket == 0)
		return;
		
	reset_fields();
		
	identifier = ticket;
	set_action(dealType);
	set_direction(vol);
	set_volume(vol);
		
	if(direction == "exit" && volume == 100)
		send_cancel_all_and_close();
	else
		send_order_signal();
}

//-------------
// Set attributes methods
//-------------
void SmarttOrder::reset_fields(void)
{
	identifier = 0;
	volume = 0.0;
	direction = "";
	action = "";
}


void SmarttOrder::set_stock_code(string stockCode)
{
	mt5_stock_code = stockCode;
	stock_code = stockCode;
	if(StringSubstr(stock_code, 0, 3) == "WIN")
		stock_code = "WIN%";
	else if(StringSubstr(stock_code, 0, 3) == "WDO")
		stock_code = "WDO%";
	else if(StringSubstr(stock_code, 0, 3) == "IND")
		stock_code = "IND%";
	else if(StringSubstr(stock_code, 0, 3) == "DOL")
		stock_code = "DOL%";
	else if(StringSubstr(stock_code, 0, 3) == "BIT")
		stock_code = "BIT%";
}

void SmarttOrder::set_action(ENUM_DEAL_TYPE type)
{
	if(type == DEAL_TYPE_BUY)
		action = "buy";
	else if(type == DEAL_TYPE_SELL)
		action = "sell";
}

void SmarttOrder::set_direction(double vol=0)
{
	/*
	Set order direction between [entry, exit, increase, reversal].
	If the order is already filled, we look at the order action and position type,
	if positioned,	to decide the direction. If not positioned, can only be an exit order.
	*/
	double owned_stocks = MathAbs(current_owned_stocks);

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
		double prev_stocks = owned_stocks - vol;
		volume = MathCeil(vol / prev_stocks * 100.0);
	}
	else if(direction == "exit")
	{
		if(positioned)
		{
			double prev_stocks = owned_stocks + vol;
			volume = vol / prev_stocks * 100.0;
			volume = full_lot() ? MathCeil(volume) : MathFloor(volume);
		}
		else
			volume = 100.0;
	}
	else if(direction == "reversal")
	{		
		double prev_stocks = vol - owned_stocks;
		volume = MathCeil(owned_stocks / prev_stocks * 100.0);
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
	
	if(volume)
		text += StringFormat(",\"quantity\":\"%s\"", DoubleToString(volume, 2));
		// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4","price":"100.00", "quantity":"50.00""

	text += "}}";
	// {"strategy":"200", "order":{"action":"buy","stock_code":"PETR4"}}
	
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
	Print(headers);
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

void SmarttOrder::update_owned_stocks(ENUM_DEAL_TYPE deal_type, double vol, double deal_price)
{	
	set_action(deal_type);
	double owned_stocks_delta = action == "buy" ? vol : -vol;
	
	update_average_price(owned_stocks_delta, deal_price);
	
	current_owned_stocks += owned_stocks_delta;
		
	PrintFormat("Owned stocks: %.2f", current_owned_stocks);
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
			Print("Olá, " + login + ". Metabot iniciado com sucesso. Versão: " + VERSION);
			first_login = false;
		}
		else
		{
			Print("Nova autenticação efetuada com sucesso.");
		}
		PrintFormat("Strategy ID: %s. Magic number: %d. Account type: %d. Versão: %s", strategy_id, magic_number, AccountInfoInteger(ACCOUNT_MARGIN_MODE), VERSION);
		
		return true;
	}
	
	return false;
}