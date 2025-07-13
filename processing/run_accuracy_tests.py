# processing/run_accuracy_tests.py

import subprocess
import time
import logging
import threading
import signal
import sys
import os
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class AccuracyTestRunner:
    def __init__(self):
        self.processes = []
        self.results = {}
        
    def start_server_if_needed(self):
        """Start the Node.js API server if not running"""
        try:
            import requests
            response = requests.get("http://localhost:3001", timeout=5)
            logging.info("API server is already running")
            return True
        except:
            logging.info("Starting API server...")
            
            # Start Node.js server in background
            api_process = subprocess.Popen(
                ['node', 'api/index.js'],
                cwd='../',
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            self.processes.append(("api_server", api_process))
            
            # Wait for server to start
            time.sleep(5)
            
            try:
                import requests
                response = requests.get("http://localhost:3001", timeout=5)
                logging.info("API server started successfully")
                return True
            except:
                logging.error("Failed to start API server")
                return False
    
    def start_calibration_api_if_needed(self):
        """Start the Flask calibration API if not running"""
        try:
            import requests
            response = requests.get("http://localhost:5001/health", timeout=5)
            logging.info("Calibration API is already running")
            return True
        except:
            logging.info("Starting calibration API...")
            
            # Start Flask calibration API in background
            cal_process = subprocess.Popen(
                ['uv', 'run', 'python', 'calibration_api/app.py'],
                cwd='../',
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            self.processes.append(("calibration_api", cal_process))
            
            # Wait for API to start
            time.sleep(3)
            
            try:
                import requests
                response = requests.get("http://localhost:5001/health", timeout=5)
                logging.info("Calibration API started successfully")
                return True
            except:
                logging.error("Failed to start calibration API")
                return False
    
    def run_test_script(self, script_name, description):
        """Run a test script and capture results"""
        logging.info(f"Running {description}...")
        
        try:
            start_time = time.time()
            
            result = subprocess.run(
                ['uv', 'run', 'python', f'{script_name}'],
                cwd='./',
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            end_time = time.time()
            duration = end_time - start_time
            
            self.results[script_name] = {
                'description': description,
                'success': result.returncode == 0,
                'duration': duration,
                'stdout': result.stdout,
                'stderr': result.stderr
            }
            
            if result.returncode == 0:
                logging.info(f"{description} completed successfully in {duration:.1f}s")
            else:
                logging.error(f"{description} failed after {duration:.1f}s")
                logging.error(f"Error: {result.stderr}")
            
        except subprocess.TimeoutExpired:
            logging.error(f"{description} timed out after 5 minutes")
            self.results[script_name] = {
                'description': description,
                'success': False,
                'duration': 300,
                'stdout': '',
                'stderr': 'Timeout after 5 minutes'
            }
        except Exception as e:
            logging.error(f"{description} crashed: {e}")
            self.results[script_name] = {
                'description': description,
                'success': False,
                'duration': 0,
                'stdout': '',
                'stderr': str(e)
            }
    
    def run_all_tests(self):
        """Run all accuracy improvement tests"""
        
        logging.info("Starting comprehensive accuracy testing...")
        
        # Ensure servers are running
        if not self.start_server_if_needed():
            logging.error("Cannot proceed without API server")
            return
        
        if not self.start_calibration_api_if_needed():
            logging.error("Cannot proceed without calibration API")
            return
        
        # Wait a bit more for servers to fully initialize
        time.sleep(3)
        
        # Test sequence
        tests = [
            ('train_calibrator.py', 'Basic Calibration Model Training'),
            ('ensemble_calibrator.py', 'Ensemble Model Training'),
            ('advanced_feature_engineering.py', 'Advanced Feature Model Training'),
            ('test_model_directly.py', 'Direct Model Testing'),
            ('debug_calibration_model.py', 'Model Debug Analysis'),
            ('validate_against_cpcb.py', 'CPCB Validation Testing')
        ]
        
        for script, description in tests:
            # Check if script exists
            script_path = f'./{script}'
            if not os.path.exists(script_path):
                logging.warning(f"Script {script} not found, skipping...")
                continue
            
            self.run_test_script(script, description)
            
            # Small delay between tests
            time.sleep(2)
        
        self.generate_report()
    
    def generate_report(self):
        """Generate comprehensive test report"""
        
        logging.info("\n" + "="*60)
        logging.info("ACCURACY IMPROVEMENT TEST REPORT")
        logging.info("="*60)
        
        total_tests = len(self.results)
        successful_tests = sum(1 for r in self.results.values() if r['success'])
        
        logging.info(f"Overall Success Rate: {successful_tests}/{total_tests} ({100*successful_tests/total_tests:.1f}%)")
        logging.info(f"Total Test Duration: {sum(r['duration'] for r in self.results.values()):.1f}s")
        
        logging.info("\nIndividual Test Results:")
        for script_name, result in self.results.items():
            status = "PASS" if result['success'] else "FAIL"
            logging.info(f"  {status} | {result['description']:40} | {result['duration']:6.1f}s")
            
            if not result['success'] and result['stderr']:
                logging.info(f"    Error: {result['stderr'][:100]}...")
        
        # Save detailed report to file
        report_file = f"./accuracy_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        with open(report_file, 'w') as f:
            f.write("ACCURACY IMPROVEMENT TEST REPORT\\n")
            f.write("="*50 + "\\n\\n")
            
            for script_name, result in self.results.items():
                f.write(f"TEST: {result['description']}\\n")
                f.write(f"Script: {script_name}\\n")
                f.write(f"Success: {result['success']}\\n")
                f.write(f"Duration: {result['duration']:.1f}s\\n")
                f.write(f"STDOUT:\\n{result['stdout']}\\n\\n")
                f.write(f"STDERR:\\n{result['stderr']}\\n\\n")
                f.write("-"*50 + "\\n\\n")
        
        logging.info(f"Detailed report saved to: {report_file}")
    
    def cleanup(self):
        """Clean up background processes"""
        logging.info("Cleaning up background processes...")
        
        for name, process in self.processes:
            try:
                process.terminate()
                process.wait(timeout=5)
                logging.info(f"Stopped {name}")
            except subprocess.TimeoutExpired:
                process.kill()
                logging.info(f"Force killed {name}")
            except Exception as e:
                logging.error(f"Error stopping {name}: {e}")
    
    def signal_handler(self, signum, frame):
        """Handle interrupt signals"""
        logging.info("\nReceived interrupt signal, cleaning up...")
        self.cleanup()
        sys.exit(0)

def main():
    runner = AccuracyTestRunner()
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, runner.signal_handler)
    signal.signal(signal.SIGTERM, runner.signal_handler)
    
    try:
        runner.run_all_tests()
    except KeyboardInterrupt:
        logging.info("\nTest execution interrupted by user")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
    finally:
        runner.cleanup()

if __name__ == "__main__":
    main()
