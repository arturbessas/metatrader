#include <SmarttOrderMultistock.mqh>
#include <Generic\HashSet.mqh>
#define ALLOWANCE_TIME 5
#define VERSION "1.0.0"

class SmarttChecker
{
	/* 
	Class responsible to check MT5 orders 
	*/
	
	CPositionInfo pos_manager;
	string authorization_token;
	CHashSet<ulong> sent_orders, checked_orders;
	CHashSet<string> stockCodeList;
	uint prev_history_orders, pending_orders;
	bool positioned;
	CHashMap<string, bool> prevPositionedMap;
	CHashSet<ENUM_ORDER_STATE> valid_states;
	bool is_staging;
	bool first_login;

	private:

	void check_pending_orders(void);
	void check_history_orders(void);
	bool get_authorization(void);
	bool check_demo_account(void);
	bool check_strategy_id(void);
	void checkStockCode(string stockCode);
	
	
	public:
	SmarttOrder smartt_order;
	SmarttChecker(void);
	~SmarttChecker(){};
	
	datetime initial_time, last_login_time;
	
	void check_authorization(void);
	bool check_initialization(void);
	void check_orders(void);		
};

SmarttChecker::SmarttChecker(void)
{
	prev_history_orders = 0;
	prev_positioned = false;
	first_login = true;
	valid_states.Add(ORDER_STATE_FILLED);
	valid_states.Add(ORDER_STATE_PLACED);
	initial_time = TimeCurrent();
	is_staging = GlobalVariableGet("SMARTTBOT_IS_STAGING") > 0;
}

void SmarttChecker::check_orders(void)
{
	//try to generate a new auth token each 120 minutes
	check_authorization();	
	//smartt_order.check_divergent_number_of_stocks();
	check_pending_orders();
	check_history_orders();	
	//string list[];
	//stockCodeList.CopyTo(list);
	//for(int i=0; i<ArraySize(list); i+)
	//	smartt_order.check_modified_position_stops(list[i]);	
}

void SmarttChecker::check_authorization(void)
{
	// only try to authenticate between 8:30 and 18:00
	MqlDateTime now;
	if(TimeCurrent(now) - last_login_time > 120 * 60 
		&& (now.hour >= 8 || (now.hour == 8 && now.min > 30)) 
		&& now.hour < 18)
		get_authorization();
}

void SmarttChecker::checkStockCode(string stockCode)
{
	if(stockCodeList.Add(stockCode))
		prevPositionedMap.Add(stockCode, false);
}

void SmarttChecker::check_pending_orders(void)
{
	pending_orders = OrdersTotal();
	for(uint i = 0; i < pending_orders; i++)
	{
		ulong ticket = OrderGetTicket(i);
		string stock_code = OrderGetString(ORDER_SYMBOL);
		if(OrderGetInteger(ORDER_MAGIC) != magic_number || (stock_code != Symbol() && !usingMultistockEa))
			continue;
					
		if(valid_states.Contains((ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE))  // consider only placed and filled orders
		&& StringFind(EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)), "STOP") < 0) // ignore start orders
		{
			if(!sent_orders.Contains(ticket))
			{
				smartt_order.new_order(ticket);
				sent_orders.Add(ticket);
				checkStockCode(stock_code);
			}
			else
				smartt_order.check_modified_order(ticket);
		}			
	}
}

void SmarttChecker::check_history_orders(void)
{
	// Check history orders (market orders go straight there)
	HistorySelect(initial_time, TimeCurrent() + 60*60);
	uint history_orders = HistoryOrdersTotal();
	
	if(history_orders > prev_history_orders)
	{	
		positioned = pos_manager.SelectByMagic(Symbol(), magic_number);
		
		//if(positioned && !prev_positioned)
		//	smartt_order.update_position_stops();
		
		// check the last 50 orders in history
		int start_index = (int)MathMax((double)history_orders - 10, 0.0);
		
		for(uint i = start_index; i < history_orders; i++)
		{
			ulong ticket = HistoryOrderGetTicket(i);
			
			if(checked_orders.Contains(ticket))
				continue; // avoid sending duplicated signals
				
			if(sent_orders.Contains(ticket))
			{
				// remove final state order from pending orders list
				smartt_order.remove_order(ticket);
				
				//if(!positioned && prev_positioned)
				//{
				// if an exit limit order was executed at MT5, wait 5s and send a cancel all and close signal
				//	Sleep(ALLOWANCE_TIME*1000);
				//	smartt_order.send_cancel_all_and_close();
				}
			}
			
			ENUM_ORDER_STATE order_state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
			string stock_code = HistoryOrderGetString(ticket, ORDER_SYMBOL);
			double volume = HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL);
			ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
			
			if((stock_code != Symbol() && !usingMultistockEa) || HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic_number)
				continue;
			
			if(order_state == ORDER_STATE_FILLED || order_state == ORDER_STATE_PARTIAL || order_state == ORDER_STATE_PLACED)
				smartt_order.update_owned_stocks(order_type, volume);
			
			if(valid_states.Contains(order_state)
			   && HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL) > 0
			   && !sent_orders.Contains(ticket))
			{						
				smartt_order.new_order(ticket, i);
				sent_orders.Add(ticket);
				//checkStockCode(stock_code);
			}
			else if(order_state == ORDER_STATE_CANCELED)
			{	
				if(pending_orders == 0)
					smartt_order.send_cancel_orders();
				else
					smartt_order.send_cancel_orders(ticket);
					
			}
			
			checked_orders.Add(ticket);
		}
		prev_history_orders = history_orders;
		//prev_positioned = positioned;
	}
}

bool SmarttChecker::get_authorization(void)
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
			
		Print("Erro no login. Tentando novamente em 60 segundos.");
		Sleep(60000);
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
		smartt_order.authorization_token = authorization_token;
		if(first_login)
		{
			MessageBox("Olá, " + login + ". Metabot iniciado com sucesso. Versão: " + VERSION);
			first_login = false;
		}
		else
		{
			Print("Nova autenticação efetuada com sucesso.");
		}
		PrintFormat("Strategy ID: %s. Magic number: %d. Account type: %d. Versão: %s", strategy_id, magic_number, AccountInfoInteger(ACCOUNT_MARGIN_MODE), VERSION);
		last_login_time = TimeCurrent();
		return true;
	}
	
	return false;
}

bool SmarttChecker::check_demo_account(void)
{
	if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
	{
		MessageBox("Só é possivel enviar sinais de uma conta DEMO. Encerrando script.");
		return false;
	}
	
	return true;
}

bool SmarttChecker::check_strategy_id(void)
{
	if(strategy_id == "")
	{
		MessageBox("Insira um ID de estratégia válido.");
		return false;
	}
	
	return true;
}

bool SmarttChecker::check_initialization(void)
{
	bool success = get_authorization() && check_strategy_id() && check_demo_account();
	
	if(success)
	{
		smartt_order.is_staging = is_staging;	
	}
	
	return success;
}