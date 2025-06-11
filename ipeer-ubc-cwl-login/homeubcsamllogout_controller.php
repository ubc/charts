<?php
/////// CWL LOGIN //////////

require_once 'vendor/autoload.php'; // Load OneLogin SAML2

/**
 * HomeController
 *
 * @uses AppController
 * @package   CTLT.iPeer
 * @author    Pan Luo <pan.luo@ubc.ca>
 * @copyright 2012 All rights reserved.
 * @license   MIT {@link http://www.opensource.org/licenses/MIT}
 */

class HomeUBCSamlLogoutController extends AppController
{
    /**
     * This controller does not use a model
     *
     * @public $uses
     */
    public $uses =  array( 'Group', 'GroupEvent',
        'User', 'UserCourse', 'Event', 'EvaluationSubmission',
        'Course', 'Role', 'UserEnrol', 'Rubric', 'Penalty');

    /**
     * __construct
     *
     * @access protected
     * @return void
     */
    function __construct()
    {
        parent::__construct();
    }

    /**
     * beforeFilter
     *
     * @access public
     * @return void
     */
    function beforeFilter()
    {


        $this->log("LOGOUT!!!!!");

        $this->_afterLogout();

        $this->redirect('https://ipeer-stg.apps.ctlt.ubc.ca/public/saml/logout.php');
        
        exit;

    }


    /**
     * index
     *
     *
     * @access public
     * @return void
     */
    function index()
    {

        $this->log("HOME:UBC SAML LOGOUT Controller:");

    }
}
