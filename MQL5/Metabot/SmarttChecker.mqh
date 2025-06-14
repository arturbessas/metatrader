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

	ulong last_checked_deal;
	CHashSet<long> positions;
	CHashMap<string,double> initial_pos_map;
		
	private:
	
	void check_history_deals(void);
	bool check_demo_account(void);
	bool check_strategy_id(void);
	bool is_valid_deal(long magicNumber, double volume, long position_id);
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
	void check_deals(void);
};

SmarttChecker::SmarttChecker(void)
{
	last_checked_deal = 0;
	initial_time = TimeCurrent();
	load_initial_positions();
}

void SmarttChecker::check_deals(void)
{
	//try to generate a new auth token each 120 minutes
	check_authorization();
		
	check_history_deals();	
}

void SmarttChecker::check_authorization(void)
{
	set_smartt_order(Symbol());
	// only try to authenticate between 8:30 and 19:00
	MqlDateTime now;
	if(TimeCurrent(now) - last_login_time > 120 * 60 
		&& (now.hour >= 8 || (now.hour == 8 && now.min > 30)) 
		&& now.hour < 19)
		smartt_order.get_authorization();
		last_login_time = TimeCurrent();
}

void SmarttChecker::check_history_deals(void)
{
	// Check history deals (all executed deals are there)
	HistorySelect(MathMax(TimeCurrent() - 60, initial_time), TimeCurrent());
	uint history_deals = HistoryDealsTotal();
	
	for(uint i = 0; i < history_deals; i++)
	{
	   ResetLastError();
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
      {
         Alert(StringFormat("Error selecting deal %d. Error: %d.", i, GetLastError()));
         break;
      }
      else if(deal_ticket <= last_checked_deal)
         continue;
         
      last_checked_deal = deal_ticket;
      
		// get deal info (state, volume, price, type, stock code)
		//ENUM_ORDER_STATE order_state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);			
		double volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
		double price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
		ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
		string stock_code = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
		ulong deal_magic = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
		long position_id = (long)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
		
		if(is_valid_deal(deal_magic, volume, position_id))
		{
			set_smartt_order(stock_code);
			smartt_order.update_owned_stocks(deal_type, volume, price);
			smartt_order.new_deal(deal_ticket, deal_type, volume);
			positions.Add(position_id);
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
	set_smartt_order(Symbol());
	
	bool success = smartt_order.get_authorization() && check_strategy_id() && check_demo_account();
	
	if(success)
	{
		last_login_time = TimeCurrent();
	}
	
	return success;
}

bool SmarttChecker::is_valid_deal(long magicNumber, double volume, long position_id)
{
	if(magicNumber != magic_number && !positions.Contains(position_id))
		return false;
		
	if(volume <= 0)
		return false;
		
	return true;
}

void SmarttChecker::set_smartt_order(string stockCode)
{
	if(!smartt_order_map.TryGetValue(stockCode, smartt_order))
	{
		double initial_position = 0;
		initial_pos_map.TryGetValue(stockCode, initial_position);		
		smartt_order_map.Add(stockCode, new SmarttOrder(stockCode, initial_position));
		smartt_order_map.TryGetValue(stockCode, smartt_order);
	}
}

void SmarttChecker::load_initial_positions(void)
{
	int count = PositionsTotal();
	ulong magic;
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
			double current_volume = 0;
			if(initial_pos_map.TryGetValue(stockCode, current_volume))
				initial_pos_map.TrySetValue(stockCode, current_volume + volume);
			else
				initial_pos_map.Add(stockCode, volume);
		}
	}
}