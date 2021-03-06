//
//  TestViewController.swift
//  ZhiTianQi
//
//  Created by 政达 何 on 2017/2/21.
//  Copyright © 2017年 政达 何. All rights reserved.
//

import UIKit

class SearchResultViewController: UITableViewController {
    let delegate = UIApplication.shared.delegate as! AppDelegate
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        CityData.filtered = filter()
        performUIUpdatesOnMain {
            self.tableView.reloadData()
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CityData.filtered.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        cell.textLabel?.text = CityData.filtered[indexPath.item].name
        return cell
    }
    
    // update CityData.filtered array based on its search string
    func filter() -> [CityForSearch]{
        let searchString = CityData.searchString.lowercased()
        return CityData.formatedData.filter(){ s in
        for item in s.matchString{
            if item.contains(searchString){
                return true
            }
        }
        return false;
        }
    }
    
}
