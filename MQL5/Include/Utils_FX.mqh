#include <Object.mqh>
#include <Generic\HashMap.mqh>

CHashMap<int, double> order_prices;

struct posManager
{
	double owned_stocks;
	double average_price;
};

double update_order_price(MqlTradeTransaction &trans)
{
	double price = 0;
	if(order_prices.TryGetValue(trans.order, price))
	{
		if(trans.price > 0)		
			order_prices.TrySetValue(trans.order,trans.price);			
	}
	else
		order_prices.Add(trans.order, trans.price);
		
	return MathMax(price,trans.price);
}

void update_position_info(MqlTradeTransaction &trans, posManager &p)
{	
	double order_price = update_order_price(trans);
	PrintFormat("id:%d - transVolume: %f - %s - Trans: %f, Price: %f", trans.order,trans.volume, EnumToString(trans.order_state), trans.price, order_price);
	if(trans.order_state != ORDER_STATE_FILLED)
		return;
		
	
	if(trans.order_type == ORDER_TYPE_BUY || trans.order_type == ORDER_TYPE_BUY_LIMIT)
		p.owned_stocks += trans.volume;
	
	else if(trans.order_type == ORDER_TYPE_SELL || trans.order_type == ORDER_TYPE_SELL_LIMIT)
		p.owned_stocks -= trans.volume;
		
	if(pos.owned_stocks != 0)
	{
		double owned_stocks = MathAbs(p.owned_stocks);
		double price = p.average_price;
		p.average_price = (((owned_stocks - trans.volume) * price) + (trans.volume * order_price)) / owned_stocks;
	}	
}


void logger(string msg)
{
	PrintFormat("id: %d - %s", magic_number, msg);
}

ENUM_MA_METHOD getTipoMedia(int tipo)
{
	switch(tipo)
	  {
	   case 1:
	      return MODE_SMA;
	      break;
	   case 2:
	      return MODE_EMA;
	      break;
	   default:
	      return MODE_EMA;
	  }
}

ENUM_TIMEFRAMES getPeriodoGrafico(int periodo)
{
	switch(periodo)
	{
	   case 1:
	      return PERIOD_M1;
	      break;
	   case 2:
	      return PERIOD_M2;
	      break;
	   case 3:
	      return PERIOD_M3;
	      break;
	   case 4:
	      return PERIOD_M4;
	      break;
	   case 5:
	      return PERIOD_M5;
	      break;
	   case 6:
	      return PERIOD_M6;
	      break;
	   case 7:
	      return PERIOD_M10;
	      break;
	   case 8:
	      return PERIOD_M12;
	      break;
	   case 9:
	      return PERIOD_M15;
	      break;
	   case 10:
	      return PERIOD_M20;
	      break;
	   case 11:
	      return PERIOD_M30;
	      break;
	   case 12:
	      return PERIOD_H1;
	      break;      
	   default:
	      return _Period;
	}
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

int time_compare(MqlDateTime &a, MqlDateTime &b)
{
	// 1 if a > b, -1 if a < b, 0 if a == b
	// only compares the time part. The date is disregarded
	
	if(a.hour > b.hour)
		return 1;
	if(a.hour < b.hour)
		return -1;
	if(a.min > b.min)
		return 1;
	if(a.min < b.min)
		return -1;
	if(a.sec > b.sec)
		return 1;
	if(a.sec < b.sec)
		return -1;
	
	return 0;
	
}