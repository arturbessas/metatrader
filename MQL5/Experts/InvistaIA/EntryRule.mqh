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

class InvistaIARule: public Node
{	
	public:
		
	void on_trade(void);
	void on_daily_reset(void);
	
	InvistaIARule(void);
	~InvistaIARule(){};
	InvistaIARule(string usedMetric, double entryPercentage, double maxLargura);
	
	private:
	string used_metric;
	double entry_percentage;
	double max_largura;
	CHashMap<datetime, double> amplitude_data;
	CHashMap<datetime, double> largura_data;
	
	double todays_amplitude;
	double todays_largura;
	void load_model_data(CHashMap<datetime, double> &ampData, CHashMap<datetime, double> &largData);
};


InvistaIARule::InvistaIARule(string usedMetric, double entryPercentage, double maxLargura)
{
	this.used_metric = usedMetric;
	this.entry_percentage = entryPercentage;
	this.max_largura = maxLargura;
   this.load_model_data(amplitude_data, largura_data);  
}

void InvistaIARule::on_daily_reset(void)
{
	if(!amplitude_data.TryGetValue(context.today, todays_amplitude)
	|| !largura_data.TryGetValue(context.today, todays_largura))
		logger.error(StringFormat("Error. Model data not found for %s", TimeToString(context.today)));
	
	logger.info(StringFormat("New day: %s. Prev amp: %f. Largura: %f.", TimeToString(context.today, TIME_DATE), todays_amplitude, todays_largura));
}

void InvistaIARule::on_trade(void)
{
   if (context.is_positioned())
      return;
   
   
   if(todays_largura > max_largura)
   	return;
   
   double min_amplitude = 0.01 * entry_percentage * todays_amplitude;
   double daily_high = iHigh(Symbol(), PERIOD_D1, 0);
   double daily_low = iLow(Symbol(), PERIOD_D1, 0);
   bool triggered = false;
		
	if(daily_high - context.current_price() >= min_amplitude)
	{
	   triggered = context.Buy(number_of_stocks, StringFormat("%.2f >= %.2f",daily_high - context.current_price(), min_amplitude));
	}
	else if(context.current_price() - daily_low >= min_amplitude)
	{
	   triggered = context.Sell(number_of_stocks, StringFormat("%.2f >= %.2f",context.current_price() - daily_low, min_amplitude));
	}
	
	if(triggered)
	   logger.info(StringFormat("Entrada enviada. High: %f; Low: %f; Preço: %f", daily_high, daily_low, context.current_price()));

}


void InvistaIARule::load_model_data(CHashMap<datetime, double> &ampData, CHashMap<datetime, double> &largData)
{
	CHashMap<string, string> *csv_data[];
	read_csv(csv_filename, csv_data);
	
	int size = ArraySize(csv_data);
	for(int i=0; i < size; i++)
	{
		string dt, amplitude_value, largura_value;
		
		if(!csv_data[i].TryGetValue(DATETIME_COLUMN, dt) 
		|| !csv_data[i].TryGetValue(used_metric, amplitude_value)
		|| !csv_data[i].TryGetValue(LARGURA_COLUMN, largura_value))
			logger.error(StringFormat("Error loading model data at line %d.", i+2));
			
		ampData.Add(datetime(dt), StringToDouble(amplitude_value));
		largData.Add(datetime(dt), StringToDouble(largura_value));
	}
	
	delete_csv(csv_data);
}