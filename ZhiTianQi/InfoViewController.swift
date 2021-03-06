//
//  InfoViewController.swift
//  ZhiTianQi
//
//  Created by 政达 何 on 2017/2/8.
//  Copyright © 2017年 政达 何. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation
class InfoViewController: UIViewController {
    // variable needed for animation
    let height : CGFloat = 148.0
    var cityCenter : CGFloat = 0.0
    var weatherCenter : CGFloat = 0.0
    // model and dataclient
    var city:City?
    var wdata:Wdata?
    let delegate = UIApplication.shared.delegate as! AppDelegate
    let client = WeatherClient.shared
    
    // variable to store the data
    var parsedDict :[String:Any] = [:]
    var tenDayForecast : [[String:Any]] = []
    var hourlyData : [[String:Any]] = []
    var currentDetail :[String:Any] = [:]
    var uiEnableFlag = false
    var locationManager: CLLocationManager? = nil
    @IBOutlet weak var scrollUpdateLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var tempScaleLabel: UILabel!
    @IBOutlet weak var todayLabel: UILabel!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var cityName: UILabel!
    @IBOutlet weak var currentView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager = delegate.locationManager
        scrollView.delegate = self
        cityCenter = cityName.center.y
        weatherCenter = weatherLabel.center.y
        tableView.separatorStyle = .none
        update()
   }
    
    // Get current location,then update the page
    @IBAction func getLocationWeather(_ sender: Any) {
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.startUpdatingLocation()
        let geo = CLGeocoder()
        if locationManager?.location != nil{
        geo.reverseGeocodeLocation((locationManager?.location!)!){ (city,error) in
            if let city = city{
            let name = city[0].name
            let stack = self.delegate.stack
            handleCity(name!,stack!)
            self.update()
            }else{
                self.alertWithError("Could not find city in your location", "Error")
                self.configureUI(false)
            }
        }
        
        }else{
            self.alertWithError("Could not locate", "Error")
        }
        locationManager?.stopUpdatingLocation()
    }
    
    
}
//MARK: - Data loading/downloading
extension InfoViewController{
    func loadWeatherData(_ handler: @escaping () -> Void){
        let stack = delegate.stack
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Wdata")
        fetchRequest.predicate = NSPredicate(format: "city == %@", city!)
        do
        {
            let results = try stack?.context.fetch(fetchRequest)
            if results!.count == 0 {
                print("no data, downloading")
                downloadData(handler)
            }else if shouldUpdate(city?.updatedAt as! Date){
                print("data out of date, downloading")
                for item in results!{
                    stack?.context.delete(item as! NSManagedObject)
                }
                downloadData(handler)
               }else{
                wdata = (results?[0] as! Wdata)
                client.parseData((self.wdata?.data)! as Data){ (dict,error) in
                parsedDict = dict as! [String : Any]
                handler()
                }
            }
        }catch{
            print("error in fetching")
            }
    }
    
    func downloadData(_ handler: @escaping () -> Void){
        let stack = delegate.stack
        let name = self.city?.name!
        var searchString = "CN/\(name!)"
        if (self.city?.location) != nil{
            searchString = (self.city?.location!)!
        }
        client.queryWithCityName(searchString){(data,error) in
            if let data = data as! NSData? {
                self.wdata  = Wdata(context:(stack?.context)!)
                self.wdata?.data = data
                self.wdata?.city = self.city
                self.city?.updatedAt = NSDate()
                stack?.save()
                self.client.parseData((self.wdata?.data)! as Data){ (dict,error) in
                self.parsedDict = dict as! [String : Any]
                }
            }else{
                self.alertWithError("Network fail","Error")
                self.configureUI(false)
             
            }
            handler()
    }
        
}
    
//MARK: - Configure UI content based on loaded data
    func configureForecast(_ forecast:[String:Any]){
        let simpleforecast = forecast["simpleforecast"] as! [String:Any]
        let forecastday = simpleforecast["forecastday"] as! [[String:Any]]
        
        for item in forecastday{
            var tempDict:[String:Any] = [:]
            if let date = item["date"] as! [String:Any]?{
                tempDict["Weekday"] = date["weekday"]
            }
            
            tempDict["Weather"] = item["conditions"]
            
            if let high = item["high"] as! [String:Any]?, let low = item["low"] as! [String:Any]?{
                let highCelsius = high["celsius"]! as! String
                if highCelsius.characters.count == 2{
                tempDict["Temp"] = "\(low["celsius"]!)   \(high["celsius"]!)"
                }else{
                tempDict["Temp"] = "\(low["celsius"]!)    \(high["celsius"]!)"

                }
            }
            tenDayForecast.append(tempDict)
        }
    }
    
    func configureHourly(_ hourly:[[String:Any]]){
        for item in hourly{
            var tempDict:[String:Any] = [:]
            let fctime = item["FCTTIME"] as! [String:Any]
            tempDict["Hour"] = fctime["hour"]
            
            let temp = item["temp"] as! [String: Any]
            tempDict["Temp"] = temp["metric"]
            
            tempDict["Condition"] = item["condition"]
            hourlyData.append(tempDict)
        }
    }
    // whether data need uodate
    func shouldUpdate(_ date:Date) -> Bool{
        let current = Date()
        let calendar = Calendar.current
        
        let currentHour = calendar.component(.hour, from: current)
        let hour = calendar.component(.hour, from: date)
        if currentHour != hour{
            return true
        }
        return false
    }
    
    func configureCurrentCondition(_ dict : [String:Any]){
        cityName.text = city?.name
        todayLabel.text = "  \(tenDayForecast[7]["Weekday"]!)   Today"
        tempScaleLabel.text = "\(tenDayForecast[0]["Temp"]!)  "
        
        let current = dict["current_observation"] as! [String:Any]
        let sunPhase = dict["sun_phase"] as! [String:Any]
        let sunrise = sunPhase["sunrise"] as! [String:Any]
        let sunset = sunPhase["sunset"] as! [String:Any]
        tempLabel.text = "\(current["feelslike_c"]!)°"
        weatherLabel.text = current["weather"] as! String?
        currentDetail["Sunrise"] = "\(sunrise["hour"]!):\(sunrise["minute"]!)"
        currentDetail["Sunset"] = "\(sunset["hour"]!):\(sunset["minute"]!)"
        currentDetail["Humidity"] = current["relative_humidity"]!
        currentDetail["Wind"] = "\(current["wind_dir"]!) \(current["wind_mph"]!) mph"
        currentDetail["Feels Like"] = "\(current["feelslike_c"]!)°"
        currentDetail["recipitation"] = "\(current["precip_today_in"]!) mm"
        currentDetail["Pressure"] = "\(current["pressure_mb"]!) hPa"
        currentDetail["Visibility"] = "\(current["visibility_km"]!) km"
        currentDetail["UV Index"] = current["UV"]!
    }
    
    func getCurrentDetail() -> String{
        var result = ""
        for item in currentDetail{
            let s = "\(item.key):  \(item.value)\n\n"
            result.append(s)
        }
        return result
    }
//MARK: - Update UI
    func configureUI(_ bool:Bool){
        if bool{
              self.tenDayForecast = []
              self.hourlyData = []
              self.configureForecast(self.parsedDict["forecast"] as! [String : Any])
              self.configureHourly(self.parsedDict["hourly_forecast"] as! [[String : Any]])
              self.configureCurrentCondition(self.parsedDict)
            performUIUpdatesOnMain {
                self.activityIndicator.stopAnimating()
            }
              self.uiEnableFlag = true
        }else{
            self.uiEnableFlag = false
            self.cityName.text = ""
            self.todayLabel.text = ""
            self.tempScaleLabel.text = ""
            self.tempLabel.text = "_ _"
            self.weatherLabel.text = ""
            performUIUpdatesOnMain {
                self.activityIndicator.startAnimating()
            }
        }
    }
    
// MARK: - whole update process
    func update(_ notCheckDB: Bool = false){
        DispatchQueue.main.async {
            self.configureUI(false)
            self.collectionView.reloadData()
            self.tableView.reloadData()
        }
        let stack = delegate.stack
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "City")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastViewedAt", ascending: false)]
        let results = try! stack?.context.fetch(fetchRequest)
        guard results?.count != 0  else{
            locationManager?.delegate = self
            if CLLocationManager.authorizationStatus().rawValue == 3{
                self.getLocationWeather(self.activityIndicator)
            }else{
                locationManager?.requestAlwaysAuthorization()
            }
            for item in CityData.commonCity{
                let _ = City(item,(stack?.context)!)
            }
            return
        }
        city = results?[0] as! City?
        city?.lastViewedAt = NSDate()
        let handler = {
            let response =  self.parsedDict["response"] as! [String:Any]?
            if response == nil || response?["error"] != nil {
                let name = self.city?.name
                self.alertWithError("Could not find data with \(name!)","Error")
                stack?.context.delete(self.city!)
            }else{
                DispatchQueue.main.async {
                    self.configureUI(true)
                    self.collectionView.reloadData()
                    self.tableView.reloadData()
                }
            }
        }
        if notCheckDB{
            downloadData(handler)
        }else{
            loadWeatherData(handler)
        }
    }
    
}
//MARK: - collectionview logic
extension InfoViewController: UICollectionViewDataSource{
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        if !uiEnableFlag{
        return 0
        }else{
            return 24
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionCell", for: indexPath) as! CollectionCell
        let hour = hourlyData[indexPath.item]
        cell.textLabel1.text = hour["Hour"] as! String?
        cell.textLabel2.text = hour["Condition"] as! String?
        cell.textLabel3.text = "\(hour["Temp"]!)°"
        return cell
    }
}
//MARK: - Tableview logic
extension InfoViewController: UITableViewDelegate,UITableViewDataSource{
    //MARK: - Animation and drag-down to update
    func scrollViewDidScroll(_ scrollView: UIScrollView){
        if scrollView == self.tableView{
        currentView.constraints[0].constant = height - scrollView.contentOffset.y
        let currentHeight = currentView.constraints[0].constant
        if currentHeight >= 0{
            
            cityName.center.y = cityCenter - 50 + currentHeight/148 * 50
            weatherLabel.center.y = weatherCenter - 50 + currentHeight/148 * 50
            
            let alpha =  (currentHeight - 78) / 78
            tempLabel.alpha = alpha
            todayLabel.alpha = alpha
            tempScaleLabel.alpha = alpha
        }
        }else{
            if scrollView.contentOffset.y < -150.0{
                scrollUpdateLabel.text = "Release to update"
            }
            else{
                scrollUpdateLabel.text = "Scroll down to update"
            }
        }
        
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == self.scrollView{
            if scrollView.contentOffset.y < -150.0{
                 update(true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0{
        let cell = tableView.dequeueReusableCell(withIdentifier: "ForecastCell") as! ForecastCell
            let forcast = tenDayForecast[indexPath.item + 1]
            cell.textLabel1.text = forcast["Weekday"] as! String?
            cell.textLabel2.text = forcast["Weather"] as! String?
            cell.textLabel3.text = forcast["Temp"] as! String?
            return cell
        }else if indexPath.section == 1{
            let cell = tableView.dequeueReusableCell(withIdentifier: "TodayOverviewCell")!
            let high = tempScaleLabel.text?.components(separatedBy: " ")[4]
            cell.textLabel?.text = "Today: \(weatherLabel.text!) currently. it's \(tempLabel.text!), the high will be \(high!)°"
            cell.textLabel?.numberOfLines = 2
            return cell
        }else{
            let  cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell")!
            cell.textLabel?.numberOfLines = 18
            cell.textLabel?.lineBreakMode = .byWordWrapping
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.text = getCurrentDetail()
            return cell
        }
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        if indexPath.section == 2{
            return 500.0
        }else{
            return 60.0
        }
    }
    
   func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0{
        return 9
    }else{
        return 1
    }
    
    }
    func numberOfSections(in tableView: UITableView) -> Int{
        if !uiEnableFlag{
            return 0
        }else
        {
        return 3
        }
    }
}

extension InfoViewController : CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status.rawValue == 3{
            getLocationWeather(activityIndicator)
        }
    }
}
