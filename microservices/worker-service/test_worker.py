"""
Unit tests for Worker service
"""
import unittest
from unittest.mock import patch, MagicMock
from worker import cleanup_old_items, process_pending_tasks, initialize_database

class TestWorkerService(unittest.TestCase):
    
    @patch('worker.get_db_connection')
    def test_initialize_database(self, mock_db):
        """Test database initialization"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_conn.cursor.return_value = mock_cursor
        mock_db.return_value = mock_conn
        
        result = initialize_database()
        self.assertTrue(result)
        mock_cursor.execute.assert_called()
    
    @patch('worker.get_db_connection')
    def test_cleanup_old_items(self, mock_db):
        """Test cleanup functionality"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.rowcount = 5
        mock_conn.cursor.return_value = mock_cursor
        mock_db.return_value = mock_conn
        
        cleanup_old_items()
        mock_cursor.execute.assert_called_once()
        mock_conn.commit.assert_called_once()
    
    @patch('worker.get_db_connection')
    def test_process_pending_tasks(self, mock_db):
        """Test task processing"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (10,)
        mock_conn.cursor.return_value = mock_cursor
        mock_db.return_value = mock_conn
        
        process_pending_tasks()
        mock_cursor.execute.assert_called_once()
    
    @patch('worker.get_db_connection')
    def test_database_unavailable(self, mock_db):
        """Test handling when database is unavailable"""
        mock_db.return_value = None
        
        # Should not raise exception
        cleanup_old_items()
        process_pending_tasks()

if __name__ == '__main__':
    unittest.main()
