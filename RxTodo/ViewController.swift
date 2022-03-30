//
//  ViewController.swift
//  RxTodo
//
//  Created by Jai Raj Sivastava on 25/03/22.
//

import RealmSwift
//import RxCocoa
import RxRealm
import RxSwift
import UIKit

class ViewController: UITableViewController {
    let realm = try! Realm()
    
    let bag = DisposeBag()

    var items: Results<Item>!
    
    var sort = 0
    
    @IBOutlet weak var todoTitle: UINavigationItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        items = realm.objects(Item.self)
        
        Observable.changeset(from: items)
            .subscribe(
                onNext: { [unowned self] _, changes in
                    if let changes = changes {
                        self.tableView.applyChangeset(changes)
                    }
                    self.tableView.reloadData()
                },
                onDisposed: {print("disposed in viewDidLoad()")}
            )
            .disposed(by: bag)

    }
    
    
    // MARK: - cell functions
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items?.count ?? 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.textLabel?.text = items?[indexPath.row].name ?? "No item."
        cell.accessoryType = items![indexPath.row].done ? .checkmark : .none
        
        return cell
    }
    
    
    // MARK: - click cell -> delete item, mark item
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "Task", message: "", preferredStyle: .alert)
        
        let action1 = UIAlertAction(title: "Delete", style: .default) { (action) in
            Observable.from([self.items[indexPath.row]])
                .subscribe(Realm.rx.delete())
                .disposed(by: self.bag)
        }
        
        let action2 = UIAlertAction(title: "Mark", style: .default) { (action) in
            try! self.realm.write {
                self.items[indexPath.row].done = !self.items[indexPath.row].done
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
            items = realm.objects(Item.self).sorted(byKeyPath: "name")
            todoTitle.title = "Todo (a -> z)"
        case 2:
            items = realm.objects(Item.self).sorted(byKeyPath: "name", ascending: false)
            todoTitle.title = "Todo (z -> a)"
        default:
            items = realm.objects(Item.self).sorted(byKeyPath: "created")
            todoTitle.title = "Todo (recent)"
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
        
//        textField.rx.controlEvent([.editingDidBegin, .editingDidEnd])
//            .asObservable()
//            .subscribe(onNext: { _ in
//                print("editing state changed")
//            })
//            .disposed(by: self.bag)
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
