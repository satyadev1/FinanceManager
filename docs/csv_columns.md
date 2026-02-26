# CSV column layout (Fin Manager – Google Drive sync)

All files are UTF-8. Use RFC 4180: quote fields that contain comma, newline, or double-quote.

## accounts.csv

| Column         | Type   | Notes                          |
|----------------|--------|---------------------------------|
| id             | string | UUID                           |
| name           | string | Account name                   |
| type           | string | `bank` or `card`               |
| balance        | number | Current balance                |
| currency       | string | e.g. INR                       |
| bank_name      | string | Optional (bank)                 |
| last_four      | string | Optional                        |
| scheme         | string | visa/mastercard/rupay/amex (card) |
| limit_amount   | number | Optional (card)                |
| limit_period   | string | monthly \| total (card)        |
| created_at     | string | ISO 8601                        |

## transactions.csv

| Column     | Type   | Notes              |
|------------|--------|--------------------|
| id         | string | UUID               |
| title      | string |                    |
| amount     | number |                    |
| type       | string | `credit` \| `debit` |
| date       | string | ISO 8601           |
| source     | string | manual \| sms \| import |
| account_id | string | Optional FK to account id |
| category   | string | Optional           |
| created_at | string | ISO 8601           |

## lending.csv

| Column       | Type   | Notes        |
|--------------|--------|--------------|
| id           | string | UUID         |
| contact_name | string |              |
| amount       | number |              |
| currency     | string |              |
| given_at     | string | ISO 8601     |
| due_at       | string | ISO 8601, optional |
| status       | string | pending, partial_returned, returned |
| notes        | string | Optional     |
| created_at   | string | ISO 8601     |
| updated_at   | string | ISO 8601     |

## loans.csv

| Column       | Type   | Notes     |
|--------------|--------|-----------|
| id           | string | UUID      |
| lender_name  | string |           |
| amount       | number |           |
| currency     | string |           |
| taken_at     | string | ISO 8601  |
| due_at       | string | ISO 8601, optional |
| status       | string | active, closed |
| interest_rate| number | Optional  |
| notes        | string | Optional  |
| created_at   | string | ISO 8601  |
| updated_at   | string | ISO 8601  |

## notifications.csv

| Column     | Type   | Notes   |
|------------|--------|---------|
| id         | string | UUID    |
| title      | string |         |
| body       | string |         |
| type       | string | info, offer, reminder |
| read       | bool   | true/false |
| created_at | string | ISO 8601 |
