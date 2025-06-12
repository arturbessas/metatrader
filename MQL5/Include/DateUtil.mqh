datetime DatetimeToDate(datetime dt)
{
	return int(dt / (60 * 60 * 24)) * (60 * 60 * 24);
}