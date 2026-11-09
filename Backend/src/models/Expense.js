const mongoose = require('mongoose');

const ExpenseSplitSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    shareAmount: {
      type: Number,
      required: true,
      min: 0,
    },
  },
  { _id: true }
);

const ExpenseSchema = new mongoose.Schema(
  {
    group: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Group',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0.01,
    },
    category: {
      type: String,
      enum: ['Food', 'Travel', 'Groceries', 'Rent', 'Shopping', 'Entertainment', 'Bills', 'Other'],
      default: 'Food',
    },
    paidBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    paidByName: {
      type: String,
      required: true,
      trim: true,
    },
    paidByEmail: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
    },
    splits: [ExpenseSplitSchema],
    note: {
      type: String,
      default: '',
      trim: true,
    },
    date: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

ExpenseSchema.index({ group: 1, date: -1 });

module.exports = mongoose.model('Expense', ExpenseSchema);

