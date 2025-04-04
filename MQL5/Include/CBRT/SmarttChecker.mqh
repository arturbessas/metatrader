#include <CBRT\SmarttOrder.mqh>
#include <Generic\HashSet.mqh>
#include <Generic\HashMap.mqh>

#define ALLOWANCE_TIME 5

bool first_login = true;
string authorization_token;

class SmarttChecker
{
	/* 
	Class responsible to check MT5 orders 
	*/
	
	CPositionInfo pos_manager;

	CHashSet<ulong> sent_orders, checked_orders;
	uint prev_history_orders, pending_orders;
	bool positioned;
	bool prev_positioned;
	CHashSet<ENUM_ORDER_STATE> valid_states;
	CHashMap<string,Position*> initial_pos_map;
	string default_stock_code;
		
	private:
	
	void check_pending_orders(void);
	void check_history_orders(void);		
	bool check_demo_account(void);
	bool check_strategy_id(void);
	bool is_valid_order(string stockCode, long magicNumber);
	void set_smartt_order(string stockCode);
	void load_initial_positions(void);
	
	
	public:
	CHashMap<string,SmarttOrder*> smartt_order_map;
	SmarttOrder *smartt_order;
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
	valid_states.Add(ORDER_STATE_FILLED);
	valid_states.Add(ORDER_STATE_PLACED);
	initial_time = TimeCurrent();
	load_initial_positions();
	if(using_multi_stocks)
		default_stock_code = "default";
	else
		default_stock_code = Symbol();
}

void SmarttChecker::check_orders(void)
{
	//try to generate a new auth token each 120 minutes
	check_authorization();
		
	
	//smartt_order.check_divergent_number_of_stocks();
	//check_pending_orders();
	check_history_orders();
	
	CKeyValuePair<string,SmarttOrder*> *smartt_order_items[];
	int count = smartt_order_map.CopyTo(smartt_order_items);
	/*for(int i = 0; i < count; i++)
	{
		smartt_order_items[i].Value().check_modified_position_stops();
	}
	*/
}

void SmarttChecker::check_authorization(void)
{
	set_smartt_order(default_stock_code);
	// only try to authenticate between 8:30 and 18:00
	MqlDateTime now;
	if(TimeCurrent(now) - last_login_time > 120 * 60 
		&& (now.hour >= 8 || (now.hour == 8 && now.min > 30)) 
		&& now.hour < 18)
		smartt_order.get_authorization();
		last_login_time = TimeCurrent();
}

void SmarttChecker::check_pending_orders(void)
{
	pending_orders = OrdersTotal();
	for(uint i = 0; i < pending_orders; i++)
	{
		ulong ticket = OrderGetTicket(i);
		string stock_code = OrderGetString(ORDER_SYMBOL);
		if(!is_valid_order(stock_code, OrderGetInteger(ORDER_MAGIC)))
			continue;
			
		set_smartt_order(stock_code);
					
		if(valid_states.Contains((ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE))  // consider only placed and filled orders
		&& StringFind(EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)), "STOP") < 0) // ignore start orders
		{
			if(!sent_orders.Contains(ticket))
			{
				smartt_order.new_order(ticket);
				sent_orders.Add(ticket);
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
		// check the last 50 orders in history
		int start_index = (int)MathMax((double)history_orders - 10, 0.0);
		
		for(uint i = start_index; i < history_orders; i++)
		{
			ulong ticket = HistoryOrderGetTicket(i);
			ENUM_ORDER_STATE order_state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);			
			double volume = HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL);
			double price = HistoryOrderGetDouble(ticket, ORDER_PRICE_CURRENT);
			ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
			
			if(checked_orders.Contains(ticket))
				continue; // avoid sending duplicated signals
			
			string stock_code = HistoryOrderGetString(ticket, ORDER_SYMBOL);
			
			if(!is_valid_order(stock_code, HistoryOrderGetInteger(ticket, ORDER_MAGIC)))
				continue;
			
			set_smartt_order(stock_code);
				
			if(sent_orders.Contains(ticket))
			{	
				Order *order;
				if(smartt_order.pending_orders.TryGetValue(ticket, order))
				{
					// if an exit limit order was executed at MT5, wait 5s and send a cancel all and close signal
					if(order_state == ORDER_STATE_FILLED && order.direction == "exit" && order.volume == 100.0)
					{
						Sleep(ALLOWANCE_TIME*1000);
						smartt_order.send_cancel_all_and_close();
					}
				}
				
				// remove final state order from pending orders list
				smartt_order.remove_order(ticket);				
			}			
			
			if(order_state == ORDER_STATE_FILLED || order_state == ORDER_STATE_PARTIAL || order_state == ORDER_STATE_PLACED)
			{
				smartt_order.update_owned_stocks(order_type, volume, price);
				//smartt_order.update_position_stops();
			}
			
			if(valid_states.Contains(order_state)
			   && HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL) > 0
			   && !sent_orders.Contains(ticket))
			{						
				smartt_order.new_order(ticket, i);
				sent_orders.Add(ticket);
			}
			/*else if(order_state == ORDER_STATE_CANCELED)
			{	
				if(pending_orders == 0)
					smartt_order.send_cancel_orders();
				else
					smartt_order.send_cancel_orders(ticket);
					
			}*/
			
			checked_orders.Add(ticket);
		}
		prev_history_orders = history_orders;
		prev_positioned = positioned;
	}
}

bool SmarttChecker::check_demo_account(void)
{
/*
	if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
	{
		MessageBox("Só é possivel enviar sinais de uma conta DEMO. Encerrando script.");
		return false;
	}
*/
	
	return true;
}

bool SmarttChecker::check_strategy_id(void)
{
	if(strategy_id < 1 || strategy_id > 6)
	{
		MessageBox("Selecione um ID de estratégia. Encerrando Metabot.");
		return false;
	}
	
	return true;
}

bool SmarttChecker::check_initialization(void)
{
	set_smartt_order(default_stock_code);
	
	if(strategy_id <= 3 && StringSubstr(Symbol(),0,3) != "WIN")
	{
		MessageBox("Verifique se o ID de estratégia selecionado corresponde ao ativo do gráfico atual. Encerrando Metabot.");
		return false;
	}
	if(strategy_id > 3 && StringSubstr(Symbol(),0,3) != "WDO")
	{
		MessageBox("Verifique se o ID de estratégia selecionado corresponde ao ativo do gráfico atual. Encerrando Metabot.");
		return false;
	}
	if(magic_number == 0)
	{
		MessageBox("Defina um magic number diferente de zero. Ele deve o mesmo usado no seu EA emissor de ordens. Encerrando Metabot.");
		return false;
	}
	MqlDateTime now;
	TimeCurrent(now);
	if(now.year > 2022 || now.mon > 8 || (now.mon == 8 && now.day > 12))
	{
		MessageBox("Script criado exclusivamente para o Campeonato Brasileiro de Robôs Traders 2022, organizado pela SmarttBot. Para se tornar um parceiro da SmarttBot, entre em contato conosco! Encerrando Metabot.");
		return false;
	}
	
	bool success = check_strategy_id() && smartt_order.get_authorization() && check_demo_account();
	
	
	
	if(success)
	{
		last_login_time = TimeCurrent();
	}
	
	return success;
}

bool SmarttChecker::is_valid_order(string stockCode, long magicNumber)
{
	if(magicNumber != magic_number)
		return false;
	if(!using_multi_stocks && StringSubstr(stockCode, 0, 3) != StringSubstr(Symbol(), 0, 3))
		return false;
	return true;
}

void SmarttChecker::set_smartt_order(string stockCode)
{
	if(!smartt_order_map.TryGetValue(stockCode, smartt_order))
	{
		Position *initial_position = NULL;
		initial_pos_map.TryGetValue(stockCode, initial_position);		
		smartt_order_map.Add(stockCode, new SmarttOrder(stockCode, initial_position));
		smartt_order_map.TryGetValue(stockCode, smartt_order);
	}
}

void SmarttChecker::load_initial_positions(void)
{
	int count = PositionsTotal();
	long magic;
	string stockCode;
	for(int i=0; i<count; i++)
	{
		pos_manager.SelectByIndex(i);
		pos_manager.InfoInteger(POSITION_MAGIC, magic);
		stockCode = pos_manager.Symbol();
		int signal = pos_manager.PositionType() == POSITION_TYPE_BUY ? 1 : -1;
		double volume = signal * pos_manager.Volume();

		if(magic == magic_number)
		{
			initial_pos_map.Add(stockCode, new Position(stockCode, volume, pos_manager.PriceOpen()));
		}
	}
}