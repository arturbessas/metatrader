#include "SmarttOrder.mqh"
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

	CHashSet<ulong> sent_orders;
	CHashSet<long> positions;
	uint prev_history_orders;
	CHashMap<string,Position*> initial_pos_map;
	string default_stock_code;
		
	private:
	
	void check_history_orders(void);		
	bool check_demo_account(void);
	bool check_strategy_id(void);
	bool is_valid_order(string stockCode, long magicNumber, ENUM_ORDER_STATE order_state, ulong ticket, double volume, long position_id);
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
		
	check_history_orders();	
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

void SmarttChecker::check_history_orders(void)
{
	// Check history orders (all executed orders are there)
	HistorySelect(initial_time, TimeCurrent() + 60*60);
	uint history_orders = HistoryOrdersTotal();
	
	if(history_orders > prev_history_orders)
	{
		prev_history_orders = history_orders;
		
		// check the last 10 orders in history
		int start_index = (int)MathMax((double)history_orders - 10, 0.0);
		
		for(uint i = start_index; i < history_orders; i++)
		{
			// get order info (ticket, state, volume, price, type, stock code)
			ulong ticket = HistoryOrderGetTicket(i);
			ENUM_ORDER_STATE order_state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);			
			double volume = HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL);
			double price = HistoryOrderGetDouble(ticket, ORDER_PRICE_CURRENT);
			ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
			string stock_code = HistoryOrderGetString(ticket, ORDER_SYMBOL);
			long order_magic = HistoryOrderGetInteger(ticket, ORDER_MAGIC);
			long position_id = HistoryOrderGetInteger(ticket, ORDER_POSITION_ID);	
			
			if(is_valid_order(stock_code, order_magic, order_state, ticket, volume, position_id))
			{
				set_smartt_order(stock_code);
				smartt_order.update_owned_stocks(order_type, volume, price);
				smartt_order.new_order(ticket, order_state, order_type, volume);
				sent_orders.Add(ticket);
				positions.Add(position_id);
			}			
		}		
	}
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
	set_smartt_order(default_stock_code);
	
	bool success = smartt_order.get_authorization() && check_strategy_id() && check_demo_account();
	
	if(success)
	{
		last_login_time = TimeCurrent();
	}
	
	return success;
}

bool SmarttChecker::is_valid_order(string stockCode, long magicNumber, ENUM_ORDER_STATE order_state, ulong ticket, double volume, long position_id)
{
	if(magicNumber != magic_number && !positions.Contains(position_id))
		return false;
	if(!using_multi_stocks && StringSubstr(stockCode, 0, 3) != StringSubstr(Symbol(), 0, 3))
		return false;
	if(order_state != ORDER_STATE_FILLED)
		return false;
	if(sent_orders.Contains(ticket))
		return false;
	if(volume <= 0)
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