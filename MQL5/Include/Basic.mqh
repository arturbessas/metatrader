void append(ulong &v[], ulong x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
	if(x == 81)
	   Print("aoba");
}

void append(double &v[], double x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
}

void append(int &v[], int x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
}

void remove_item(ulong &v[], ulong x)
{
   int size = ArraySize(v);
   for(int i=0;i<size;i++)
   {
      if (v[i] == x)
      {
         ArrayRemove(v, i, 1);
         return;
      }
   }
}

void remove_item(double &v[], double x)
{
   int size = ArraySize(v);
   for(int i=0;i<size;i++)
   {
      if (v[i] == x)
         ArrayRemove(v, i, 1);
         return; 
   }
}

bool contains(ulong &v[], ulong x)
{
   int size = ArraySize(v);
   for(int i=0;i<size;i++)
   {
      if (v[i] == x)
         return true; 
   }
   
   return false;
}

bool contains(double &v[], double x)
{
   int size = ArraySize(v);
   for(int i=0;i<size;i++)
   {
      if (v[i] == x)
         return true; 
   }   
   return false;
}

bool is_buy_order_type(ENUM_ORDER_TYPE order_type)
{
   if (order_type == ORDER_TYPE_BUY
   || order_type == ORDER_TYPE_BUY_LIMIT
   || order_type == ORDER_TYPE_BUY_STOP
   || order_type == ORDER_TYPE_BUY_STOP_LIMIT)
      return true;
   
   return false;
}

bool is_sell_order_type(ENUM_ORDER_TYPE order_type)
{
   if (order_type == ORDER_TYPE_SELL
   || order_type == ORDER_TYPE_SELL_LIMIT
   || order_type == ORDER_TYPE_SELL_STOP
   || order_type == ORDER_TYPE_SELL_STOP_LIMIT)
      return true;
   
   return false;
}

#define SECONDS_IN_A_DAY (60*60*24)

datetime DatetimeToDate(datetime dt)
{
	return int(dt / SECONDS_IN_A_DAY) * SECONDS_IN_A_DAY;
}

datetime DatetimeToTime(datetime dt)
{
	return dt % SECONDS_IN_A_DAY;
}