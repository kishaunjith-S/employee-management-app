const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const dotenv = require('dotenv');
dotenv.config();
const app = express();
const port = process.env.PORT || 3000;
app.use(cors()); // Allow all origins for development
app.use(express.json());
const pool = new Pool({
  user: process.env.DB_USER || 'your_username',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'employee_db',
  password: process.env.DB_PASSWORD || 'your_password',
  port: process.env.DB_PORT || 5432,
});
pool.on('connect', () => {
  console.log('Connected to PostgreSQL database');
});
pool.on('error', (err) => {
  console.error('Unexpected error on idle client:', err.stack);
  process.exit(-1);
});
app.get('/api/employees', async (req, res) => {
  try {
    const { namePrefix } = req.query;
    let query = 'SELECT * FROM employees';
    let values = [];
    if (namePrefix) {
      query += ' WHERE name ILIKE $1';
      values.push(`${namePrefix}%`);
    }
    query += ' ORDER BY name';
    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching employees:', err.stack);
    res.status(500).json({ error: 'Database error while fetching employees' });
  }
});
app.post('/api/employees', async (req, res) => {
  const { name, salary, role } = req.body;
  if (!name || typeof name !== 'string') {
    return res.status(400).json({ error: 'Name is required and must be a string' });
  }
  if (typeof salary !== 'number' || salary <= 0) {
    return res.status(400).json({ error: 'Salary is required and must be a positive number' });
  }
  if (!role || typeof role !== 'string') {
    return res.status(400).json({ error: 'Role is required and must be a string' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO employees (name, salary, role) VALUES ($1, $2, $3) RETURNING *',
      [name, salary, role]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error adding employee:', err.stack);
    res.status(500).json({ error: 'Database error while adding employee' });
  }
});
app.put('/api/employees/:id', async (req, res) => {
  const { id } = req.params;
  const { name, salary, role } = req.body;
  if (!name || typeof name !== 'string') {
    return res.status(400).json({ error: 'Name is required and must be a string' });
  }
  if (typeof salary !== 'number' || salary <= 0) {
    return res.status(400).json({ error: 'Salary is required and must be a positive number' });
  }
  if (!role || typeof role !== 'string') {
    return res.status(400).json({ error: 'Role is required and must be a string' });
  }
  try {
    const parsedId = parseInt(id);
    if (isNaN(parsedId) || parsedId <= 0) {
      return res.status(400).json({ error: 'ID must be a positive integer' });
    }
    const result = await pool.query(
      'UPDATE employees SET name = $1, salary = $2, role = $3 WHERE id = $4 RETURNING *',
      [name, salary, role, parsedId]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating employee:', err.stack);
    res.status(500).json({ error: 'Database error while updating employee' });
  }
});
app.delete('/api/employees/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const parsedId = parseInt(id);
    if (isNaN(parsedId) || parsedId <= 0) {
      return res.status(400).json({ error: 'ID must be a positive integer' });
    }
    const result = await pool.query('DELETE FROM employees WHERE id = $1', [parsedId]);
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Employee not found' });
    }
    res.status(204).send();
  } catch (err) {
    console.error('Error deleting employee:', err.stack);
    res.status(500).json({ error: 'Database error while deleting employee' });
  }
});
const server = app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Closing server...');
  server.close(() => {
    pool.end(() => {
      console.log('Database pool closed.');
      process.exit(0);
    });
  });
});