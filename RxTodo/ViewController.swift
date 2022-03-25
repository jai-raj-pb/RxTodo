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

class ViewController: UITableViewController {
    let realm = try! Realm()
    
    let bag = DisposeBag()

    var items: Results<Item>!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        items = realm.objects(Item.self)
        
        Observable.changeset(from: items)
          .subscribe(onNext: { [unowned self] _, changes in
            if let changes = changes {
              self.tableView.applyChangeset(changes)
            } else {
              self.tableView.reloadData()
            }
          })
          .disposed(by: bag)

    }
    
    // MARK: - cell functions
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items?.count ?? 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.textLabel?.text = items?[indexPath.row].name ?? "No item."
        
        return cell
    }
    
    // MARK: - click cell -> delete item
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
      Observable.from([items[indexPath.row]])
        .subscribe(Realm.rx.delete())
        .disposed(by: bag)
    }

    // MARK: - add item to cell 
    @IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
        var textField = UITextField()
        
        let alert = UIAlertController(title: "Add new Category", message: "", preferredStyle: .alert)

        let action = UIAlertAction(title: "Add Category", style: .default) { (action) in
            let newItem = Item()
            newItem.name = textField.text!
            Observable.from(object: newItem)
                .subscribe(Realm.rx.add())
                .disposed(by: self.bag)
        }

        alert.addTextField { (alertTextField) in
            alertTextField.placeholder = "Create new Category"
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
