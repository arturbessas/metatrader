// ---------------
// ---------------
// Strategy rule
// ---------------
// ---------------

/*
#include <Enums.mqh>
#include <Context.mqh>
Context *context;
 */

class IADistRule: public Node
{	
	public:
		
	void on_trade(void);
	void on_daily_reset(void);
	
	IADistRule(void);
	~IADistRule(){};
	IADistRule(string usedMetric, int maPeriod, double Distance, bool Trendwie);
	
	private:
	string used_metric;
	double distance;
	int ma_period;
	bool trendwise;
	int mediaHandle;
   double aux[];

	CHashMap<datetime, double> amplitude_data;
	
	double min_amplitude;

	void load_model_data(CHashMap<datetime, double> &ampData);
};


IADistRule::IADistRule(string usedMetric, int maPeriod, double Distance, bool Trendwise)
{
	this.used_metric = usedMetric;
	this.ma_period = maPeriod;
	this.distance = Distance;
	this.trendwise = Trendwise;
   this.load_model_data(amplitude_data);
   
   //Set up moving average
   ArraySetAsSeries(aux,true);
	mediaHandle = iMA(_Symbol,context.periodicity,ma_period,0,MODE_EMA,PRICE_CLOSE);
}

void IADistRule::on_daily_reset(void)
{
	if(!amplitude_data.TryGetValue(context.today, min_amplitude))
		logger.error(StringFormat("Error. Model data not found for %s", TimeToString(context.today)));
	
	logger.info(StringFormat("New day: %s. Min amp: %f.", TimeToString(context.today, TIME_DATE), min_amplitude));
}

void IADistRule::on_trade(void)
{
   if (context.is_positioned())
      return;
   
   double daily_high = iHigh(Symbol(), PERIOD_D1, 0);
   double daily_low = iLow(Symbol(), PERIOD_D1, 0);
   double current_amplitude = daily_high - daily_low;
   
   if(current_amplitude < min_amplitude)
   	return;
   
   // get moving average
   CopyBuffer(mediaHandle,0,0,1,aux);
   double moving_average = aux[0];
   
   bool triggered = false;
   double price = context.current_price();
   
   bool is_below_range = price <= MathMin(moving_average - distance, daily_high - min_amplitude);
	bool is_above_range = price >= MathMax(moving_average + distance, daily_low + min_amplitude);

	if ((!trendwise && is_below_range) || (trendwise && is_above_range))
	{
	   triggered = context.Buy(number_of_stocks, StringFormat("P: %.2f; MA: %.2f", price, moving_average));
	}
	else if((trendwise && is_below_range) || (!trendwise && is_above_range))
	{
	   triggered = context.Sell(number_of_stocks, StringFormat("P: %.2f; MA: %.2f", price, moving_average));
	}
	
	if(triggered)
	   logger.info(StringFormat("Entrada enviada. Current amp: %.2f; Min amp: %.2f; MA: %.2f", current_amplitude, min_amplitude, moving_average));

}


void IADistRule::load_model_data(CHashMap<datetime, double> &ampData)
{
	CHashMap<string, string> *csv_data[];
	read_csv(csv_filename, csv_data);
	
	int size = ArraySize(csv_data);
	for(int i=0; i < size; i++)
	{
		string dt, amplitude_value;
		
		if(!csv_data[i].TryGetValue(DATETIME_COLUMN, dt) 
		|| !csv_data[i].TryGetValue(used_metric, amplitude_value))
			logger.error(StringFormat("Error loading model data at line %d.", i+2));
			
		ampData.Add(datetime(dt), StringToDouble(amplitude_value));
	}
	
	delete_csv(csv_data);
}