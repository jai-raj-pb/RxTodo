//
//  ViewController.swift
//  RxTodo
//
//  Created by Jai Raj Sivastava on 25/03/22.
//

import RealmSwift
import RxCocoa
import RxRealm
import RxSwift
import UIKit
import SwiftUI
import WebKit

class ViewController: UITableViewController {
    
    let bag = DisposeBag()

    let realm = try! Realm()
    var items: Results<Item>!
    var filteredItems: Results<Item>!
    
    let searchController = UISearchController(searchResultsController: nil)
    var isFiltering: Bool {
      return searchController.isActive && !isSearchBarEmpty
    }
    var isSearchBarEmpty: Bool {
      return searchController.searchBar.text?.isEmpty ?? true
    }
    
    var sort = 0
    let sortingType = BehaviorRelay<(String, Bool)> (value: ("created", false))
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Todo (recent)"
        
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Task"
        navigationItem.searchController = searchController
        
        items = realm.objects(Item.self).sorted(byKeyPath: "created", ascending: false)
        sortingType.subscribe(onNext: { (sortType, isAsc) in
            self.items = self.realm.objects(Item.self).sorted(byKeyPath: sortType, ascending: isAsc)
        }).disposed(by: bag)
        
        
        Observable.changeset(from: items)
            .subscribe(
                onNext: { [unowned self] _, changes in
                    if let changes = changes {
                        self.tableView.applyChangeset(changes)
//                        print("applying")
                    }
                    self.tableView.reloadData()
                },
                onDisposed: {print("disposed in viewDidLoad()")}
            )
            .disposed(by: bag)

    }
    
    
    // MARK: - cell functions
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isFiltering ? filteredItems.count : items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
//        cell.textLabel?.text = items?[indexPath.row].name ?? "No item."
//        cell.accessoryType = items![indexPath.row].done ? .checkmark : .none
//
        if isFiltering {
            cell.textLabel?.text = filteredItems?[indexPath.row].name ?? "No item."
            cell.accessoryType = filteredItems![indexPath.row].done ? .checkmark : .none
        } else {
            cell.textLabel?.text = items?[indexPath.row].name ?? "No item."
            cell.accessoryType = items![indexPath.row].done ? .checkmark : .none
        }
        
        return cell
    }
    
    
    // MARK: - click cell -> delete item, mark item
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "Task", message: "", preferredStyle: .actionSheet)
        
        let action1 = UIAlertAction(title: "Delete", style: .destructive) { (action) in
            Observable.from([self.isFiltering ? self.filteredItems[indexPath.row] : self.items[indexPath.row]])
//                .subscribe(onNext: { item in
//                    print(item)
//                    self.realm.delete(item)
//                })
                .subscribe(Realm.rx.delete())
                .disposed(by: self.bag)
        }
//
        let action2 = UIAlertAction(title: "Mark", style: .default) { (action) in
            try! self.realm.write {
                if self.isFiltering {
                    self.filteredItems[indexPath.row].done = !self.filteredItems[indexPath.row].done
                } else {
                    self.items[indexPath.row].done = !self.items[indexPath.row].done

                }
            }
        }
        alert.addAction(action1)
        alert.addAction(action2)
        present(alert, animated: true, completion: nil)
        
        
    }

    // MARK: - sort
    @IBAction func sortButtonPressed(_ sender: UIBarButtonItem) {

        sort = (sort + 1) % 3

        switch(sort) {
        case 1:
            sortingType.accept(("name", true))
//            items = realm.objects(Item.self).sorted(byKeyPath: "name")
            self.title = "Todo (a -> z)"
        case 2:
            sortingType.accept(("name", false))
//            items = realm.objects(Item.self).sorted(byKeyPath: "name", ascending: false)
            self.title = "Todo (z -> a)"
        default:
            sortingType.accept(("created", false))
//            items = realm.objects(Item.self).sorted(byKeyPath: "created", ascending: false)
            self.title = "Todo (recent)"
        }

        self.tableView.reloadData()
    }
    
    // MARK: - add item to cell
    @IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
        var textField = UITextField()
        
        let alert = UIAlertController(title: "Add new task", message: "", preferredStyle: .alert)

        let action = UIAlertAction(title: "Add task", style: .default) { (action) in
            let newItem = Item()
            newItem.name = textField.text!
            newItem.created = Date()
            Observable.from(object: newItem)
                .subscribe(Realm.rx.add())
                .disposed(by: self.bag)
        }

        alert.addTextField { (alertTextField) in
            alertTextField.placeholder = "Create new task"
            textField = alertTextField
        }

        alert.addAction(action)

        present(alert, animated: true, completion: nil)
    }
}


extension UITableView {
  func applyChangeset(_ changes: RealmChangeset) {
    beginUpdates()
    deleteRows(at: changes.deleted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
    insertRows(at: changes.inserted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
    reloadRows(at: changes.updated.map { IndexPath(row: $0, section: 0) }, with: .automatic)
    endUpdates()
  }
}


extension ViewController : UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        searchBar
            .rx.text
            .orEmpty
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [self] query in
                print("qry \(query)")
                filteredItems = items?.filter("name CONTAINS[cd] %@", query)
                self.tableView.reloadData()
            })
            .disposed(by: bag)
    }
    
}

